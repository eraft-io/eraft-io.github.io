```
  616  wget https://cdn.mysql.com//Downloads/MySQL-8.0/mysql-8.0.28.tar.gz
  617  ls
  618  tar -zxvf mysql-8.0.28.tar.gz
  619  ls
  620  cd mysql-8.0.28
  621  ls
  622  mkdir bld
  623  cd bld/
  624  ls
  625  cmake ..
  626  apt install gcc-8 g++-8 -y
  627  ls
  628  cmake ..
  629  cmake -DWITH_BOOST=/usr/local/boost ..
  630  mkdir /usr/local/boost
  631  ls
  632  cmake -DWITH_BOOST=/usr/local/boost ..
  633  cmake -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/usr/local/boost ..
  634  htop
  635  top
  636  apt-get install htop
  637  htop
  638  ls
  639  make -j12
  640  ls
  641  cd mysql-test/
  642  ls
  643  ./mysql-test-run
  657  ./bin/mysqld --no-defaults --user=root --initialize-insecure --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
  663  ./bin/mysqld --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data --socket=/usr/local/mysql/mysql.sock --user=root
```
