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
