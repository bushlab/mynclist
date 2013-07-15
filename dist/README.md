MyNCList
========

View the [main project page](https://github.com/bushlab/mynclist) for the full README.

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

	cd dist/
	sudo MyNCList-install.sh

or

	cd dist/
	sudo MyNCList-install.sh --mysql

If access to MySQL is not available, the second option will install mysql 
onto your local linux machine, and create a database called `nclist` to be 
used by MyNCList. Users should update their configuration files to reflect
this information.

Users with access to MySQL should create this database manually and specify
the information in the configuration file. MyNCList.py will not attempt to 
create, delete, or modify any database besides those specified in
configuration files.

For manual Linux installation: 

	cd dist/
	tar -zxvf MyNCList-1.0.tar.gz
	cd MyNCList-1.0
	sudo python setup.py install

For manual Windows installation: 

	cd dist/
	-Unzip MyNCList-1.0.zip-
	cd MyNCList-1.0
	python setup.py install
