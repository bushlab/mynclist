This installation requires the python distribution package: setuptools. 
If setuptools is not installed, you may download it from pypi:
https://pypi.python.org/pypi/setuptools


Automated Linux install:
1. Change directory into dist/
2a. `sudo MyNCList-install.sh`
2b. `sudo MyNCList-install.sh --mysql`

Option 2b will install mysql onto your local linux machine.


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