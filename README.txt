This installation requires the python distribution package: setuptools. 
If setuptools is not installed, you may download it from pypi:
https://pypi.python.org/pypi/setuptools


Automated Linux install:
1a. `sudo MyNCList-install.sh`
1b. `sudo MyNCList-install.sh --mysql`

Option 1b will install mysql onto your local linux machine.


For manual Linux installation:
1. `tar -zxvf dist/MyNCList-1.0.tar.gz`
2. `sudo python setup.py install`

For manual Windows installation:
1. Unzip dist/MyNCList-1.0.zip
2. `python setup.py install`