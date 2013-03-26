#!/bin/bash

#####
# Install script for MyNCList
# Adds MyNCList.py to Python Scripts directory as executable.
# Installs required python modules and MySQL if specfied.
#####

export PATH=$PATH:/usr/local/bin/
echo ""
echo "Installing MyNCList.py and dependencies..."
tar -zxvf MyNCList-1.0.tar.gz
cd MyNCList-1.0
python setup.py install

# Use if global installation permissions not available
#python MyNCList-1.0/setup.py install --prefix

if [ "$1"="--mysql" ]; then

  if ! command `mysql --help > /dev/null 2>&1`; then
    echo ""
    echo "Installing mysql locally..."
      yum install mysql
      yum install mysql-server
      yum install mysql-devel
      chgrp -R mysql /var/lib/mysql
      chmod -R 770 /var/lib/mysql
      service mysqld start
  else
    echo ""
    echo "Local mysql installation exists."
  fi

  echo "Dropping nclist database"
  mysql -u root -e "DROP DATABASE nclist"
  echo ""
  echo "Creating nclist database"
  mysql -u root -e "CREATE DATABASE nclist"
fi

echo ""
echo "Installation complete."
exit 0