# Gitsh installation 

this is a simple bash script that makes  **Git** easier to use with a simple and easy interface.

 It supports basic git functions.
 
**adding,
committing,
pushing,
branch management,
fetching and pulling and more**

**How to install**
```
git clone https://github.com/saninkasjrr/jubilant-octo-spoon.git
```

**Navigate to the folder**                   
```
cd jubilant-octo-spoon
```


**Make file executable**
```
chmod +x git.sh
```

**Make it accessible everywhere**
on **Termux**
```
cp git.sh /data/data/com.termux/files/usr/bin/gitsh
```

on **Linux**
```
sudo cp git.sh /usr/local/bin/gitsh
```

**remove directory**
```
sudo rm -rf ../jubilant-octo-spoon
```
# Gitsh Usage 

to use it, simply type gitsh into your terminal, and that's it.
```
gitsh
```

**Using shorthand syntax**
once you are familiar with it, you can use shorthand syntax to quickly perform operations, for example **gitsh 1** to add abd commit, **gitsh 2** to push and so on.

```
gitsh 1 //to add and commit.
```

```
gitsh 2 //for pushing
```

```
gitsh 3 //for branch management(switching branches and more)
```

****
just memorize what the numbers are for, and you are good to use the shorthand
****

*thank you for using gitsh.*
