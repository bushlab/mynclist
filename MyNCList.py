#!/usr/bin/python

# File: MyNCList.py
#
# Author: R. Michael Sivley, Vanderbilt University Medical Center, CHGR
# Email:  mike.sivley@vanderbilt.edu
#
# Description:
#   Stores a standard BED file into a MySQL MyISAM database using a nested
# annotation tree. Also creates stored MySQL procedures by which the user
# can rapidly annotate data. Locations to be annotated should be loaded
# into a search table before making the call to MyNCList_Query.
#   The NCList structure drastically reduces the time needed to annotate
# data over traditional database indexing strategies.

# Dependencies
import os,sys,time,csv,MySQLdb
from collections import deque

# Global variable definitions
ranges = []
config = {}


class Node:
	"""
		Node class for use in a tee structure. Each node represents an
	annotationrange, the annotation, and a list of other Nodes nested within
	it's range. Used to build a tree with dummy coded 0 Node as the root.
	"""
	# Class variable definitions
	subid = -1
	# Constructor
	def __init__(self,annotation=(float("-inf"),float("inf"),"")):
		self.start   = annotation[0]
		self.end     = annotation[1]
		self.exon_id = annotation[2]
		self.sublist = []
		Node.subid  += 1
		self.sub     = Node.subid

def main(configfile):
	"""
		Reads the configuration file passed to MyNCList and performs the
	necessary operations to create an annotation tree. That annotation tree
	is saved to file and uploaded to the specified MySQL database. Predefined
	MySQL procedures are also created to facilitate querying and annotation
	range insertion and deletion.
	"""
	global ranges,config

	t0 = time.time()

	# Read the config file
	with open(configfile,'r') as fin:
		reader = csv.reader(fin,delimiter=' ',skipinitialspace=True)
		config = dict((row[0],row[1]) for row in reader if len(row) > 1)

	# Read the offsets file
	with open(config['offset'],'r') as fin:
		reader = csv.reader(fin,delimiter='\t')
		offsets = dict((row[0],int(row[1])) for row in reader)

	print("Reading annotation ranges from bed...")
	with open(config['bedfile'],'r') as fin:
		fin.readline()
		reader = csv.reader(fin,delimiter='\t')
		# Only read ranges on chromosomes for which an offset is specified
		ranges = [(int(row[1])+offsets[row[0][3:]],
				   int(row[2])+offsets[row[0][3:]],
				   row[3]) for row in reader if row[0][3:] in offsets]

	print("Sorting ranges by `start`...")
	ranges.sort()
	ranges = deque(ranges)

	# If reports requested, write offset ranges to file
	if 'reports' in config and config['reports'] == 'yes':
		print("Writing offset ranges to file...")
		with open('%(workdir)s/offsetexons.txt' % config,'w') as fout:
			fout.write("start\tend\texon_id\n")
			for tup in ranges:
				fout.write("%d\t%d\t%s\n"%(tup[0],tup[1],tup[2]))

	print("Building annotation tree and writing to files...")
	if not os.path.exists('%(workdir)s' % config):
		os.mkdir('%(workdir)s' % config)
	with open('%(workdir)s/%(label)s.node' % config,'w') as fout_node:
		with open('%(workdir)s/%(label)s.edge' % config,'w') as fout_edge:
			with open('%(workdir)s/%(label)s.masterkey' % config,'w') as fout_masterkey:
				# Write the headers for the tree files
				fout_node.write("start\tend\texon_id\trangeid\tsub\n")
				fout_edge.write("range_id\tsub\n")
				fout_masterkey.write("range_id\tdatabase_ids\n")
				# Parse the tree and write the values to tree files
				build_sublist(node=Node(),fout_node=fout_node,fout_edge=fout_edge,fout_masterkey=fout_masterkey)

	print("Populating database and creating procedures...")
	with MySQLdb.connect(host=config['dbhost'],user=config['dbuser'],passwd=config['dbpass'],db=config['db']) as con:
		create_table(con=con)
		load_procedures(con=con)
		load_tree(con=con)

	print("\nFinished in %2.2fs." % (time.time()-t0))

def build_sublist(node,fout_node,fout_edge,fout_masterkey):
	"""
		Recursive function for constructing an annotation tree from a deque
	of annotation ranges. The default priority is to nest a range within the
	first valid containing range. If `membership` is set to `last` in the
	configuration file, ranges will be placed into the last valid containing
	range. The tree is built in O(N) time and the nodes are written to file
	as the tree is built.
	"""
	global ranges,config
	front = (0 if 'membership' in config and config['membership'] == 'last' else -1)
	while ranges and ranges[front][0] >= node.start and ranges[front][1] <= node.end:
		sub_node = (Node(ranges.popleft()) if front > -1 else Node(ranges.pop()))
		if sub_node.sub > 0:
			write_node(sub_node,node,fout_node,fout_edge,fout_masterkey)
		node.sublist.append(build_sublist(sub_node,fout_node,fout_edge,fout_masterkey))
	return node

def write_node(node,parent,fout_node,fout_edge,fout_masterkey):
	"""
	Given a node and its parent, adds the node to the tree files.
	"""
	fout_node.write("%d\t%d\t%d\t%d\n" % (node.start,node.end,node.sub,parent.sub))
	fout_edge.write("%d\t%d\n" % (node.sub,node.sub))
	fout_masterkey.write("%d\t%s\n" % (node.sub,node.exon_id))

def create_table(con):
	"""
		Creates the node, edge, and masterkey tables in the database specified in
	the config file. Drops any existing tables.
	"""
	global config
	try:
		con.execute("DROP TABLE IF EXISTS %(db)s.%(label)s_node;" % config)
		con.execute("DROP TABLE IF EXISTS %(db)s.%(label)s_edge;" % config)
		con.execute("DROP TABLE IF EXISTS %(db)s.%(label)s_masterkey;" % config)
	except MySQLdb.Warning:
		pass # Ignore warnings when tables do not exist
	con.execute("CREATE TABLE %(db)s.%(label)s_node (start BIGINT UNSIGNED DEFAULT NULL, end BIGINT UNSIGNED DEFAULT NULL, range_id INT UNSIGNED NOT NULL, sub INT UNSIGNED DEFAULT NULL, KEY sub_start_end (sub, start, end), KEY start_end (start, end), KEY range_id (range_id)) engine = MyISAM default charset = latin1;" % config)
	con.execute("CREATE TABLE %(db)s.%(label)s_edge (range_id INT UNSIGNED NOT NULL, sub INT UNSIGNED NOT NULL, PRIMARY KEY (range_id, sub)) engine = MyISAM default charset = latin1;" % config)
	con.execute("CREATE TABLE %(db)s.%(label)s_masterkey (range_id INT UNSIGNED NOT NULL, database_ids TEXT, PRIMARY KEY (range_id)) engine = MyISAM default charset = latin1;" % config)

def load_procedures(con):
	"""
		Creates the query, insert, and remove procedures associated with the
	NCList tree structure.
	"""
	global config
	try:
		con.execute("DROP PROCEDURE IF EXISTS MyNCList_Query;")
		con.execute("DROP PROCEDURE IF EXISTS MyNCList_Insert_Interval;")
		con.execute("DROP PROCEDURE IF EXISTS MyNCList_Remove_Interval;")
	except MySQLdb.Warning:
		pass # Ignore warnings when tables do not exist
	with open('create_stored_proc_mynclist_query.sql','r') as fin:
		con.execute(fin.read())
	with open('create_stored_proc_mynclist_interval.sql','r') as fin:
		con.execute(fin.read())
	with open('create_stored_proc_mynclist_remove_interval.sql','r') as fin:
		con.execute(fin.read())

def load_tree(con):
	"""
		Loads the node, edge, and masterkey tables from the tree files generated
	by parse_tree().
	"""
	global config
	con.execute("LOAD DATA LOCAL INFILE '%(workdir)s/%(label)s.node' INTO TABLE %(db)s.%(label)s_node IGNORE 1 LINES;" % config)
	con.execute("LOAD DATA LOCAL INFILE '%(workdir)s/%(label)s.edge' INTO TABLE %(db)s.%(label)s_edge IGNORE 1 LINES;" % config)
	con.execute("LOAD DATA LOCAL INFILE '%(workdir)s/%(label)s.masterkey' INTO TABLE %(db)s.%(label)s_masterkey IGNORE 1 LINES;" % config)

if __name__ == "__main__":
	# Pass the config filename to main()
	main(sys.argv[1])