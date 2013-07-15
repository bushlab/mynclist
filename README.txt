MyNCList
========

Overview
--------
MyNCList is an implementation of the NCList data structure within a MySQL
database. The included python script reads data stored in a .BED file,
organizes it into the NCList structure and uploads the data to MySQL, where
stored procedures allow for in-place insertions and deletions, along with
efficient interval-based querying.

Dependencies
------------
MyNCList requires Python2.7, `MySQL-python`, and a MySQL database in 
which to store the NCList structure. Installation should automatically
install `MySQL-python` and can install MySQL locally if specified.
If `setuptools` is not installed, you may download it from pypi:
https://pypi.python.org/pypi/setuptools

Installation
------------
It is recommended that users install from the contents of dist/.

Automated Linux install:
1. Change directory into dist/
2a. `sudo MyNCList-install.sh`
2b. `sudo MyNCList-install.sh --mysql`

If access to MySQL is not available, option 2b will install mysql onto your
local linux machine, and create a database called `nclist` to be used by
MyNCList. Users should update their configuration files to reflect this 
information.

Users with access to MySQL should create this database manually and specify
the information in the configuration file. MyNCList.py will not attempt to 
create, delete, or modify any database besides those specified in
configuration files.

For manual Linux installation:
1. `cd dist/`
2. `tar -zxvf MyNCList-1.0.tar.gz`
3. `cd MyNCList-1.0`
4. `sudo python setup.py install`

For manual Windows installation:
1. `cd dist/`
2. Unzip MyNCList-1.0.zip
3. `cd MyNCList-1.0`
4. `python setup.py install`

Configuration Files
-------------------
Configuration options for MyNCList should be specified in a config file, with
a space separating the configuration parameter and its value. A sample config
file is included with the distributable. MySQL tables will be created following
the convention `DBNAME`.`LABEL_TABLENAME` (e.g. `nclist`.`sample_masterkey`)
and will overwrite existing tables if necessary, so unique labels are strongly
encouraged.

Database Parameters:
* DBHOST		# MySQL hostname
* DBUSER		# MySQL user
* DBPASS		# MySQL password
* DBNAME		# MySQL database

Required Parameters:
* BEDFILE		# Location of source .BED file
* OFFSET 		# Location chromosome base position offsets file
* WORKDIR		# Working directory for intermediate files
* LABEL			# Label for this set of annotations

Optional Parameters:
* MEMBERSHIP	# Nest interval within the [first,last] valid parent
* REPORTS		# Output additional intermediate files? [yes,no]
* CONCAT_DUPS	# Concatenate annotations for duplicate intervals? [yes,no]
