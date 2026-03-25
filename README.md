# Linuxmuster Fileserver

This tool installs a file server and joins it to the Linuxmuster server's AD. The share is configured on the server for the specified school and can then be integrated into the Linuxmuster server via the DFS configuration. All home drives, share drives, and project drives are then located on the separate file server.

## Benefits

- Separation of services (AD on the Linux sample server, files on the file server)
- Better backup strategy (files can be backed up separately from the AD)
- Security (a separate file server can be used for each school (multi-school setup))
- Easy maintenance and updates (AD remains available during a file server restart or update)
- Performance improvement (see [Performance improvement](#performance-improvement))

## Maintenance Details
Linuxmuster.net official | ✅  YES
:---: | :---: 
[Community support](https://ask.linuxmuster.net) | ✅  YES*
Actively developed | ✅  YES
Maintainer organisation |  Linuxmuster.NET
Primary maintainer | lukas.spitznagel@netzint.de  
    
\* The linuxmuster community consist of people who are nice and happy to help. They are not directly involved in the development though, and might not be able to help in all cases.

## Installation

### 1. Import key

```bash
wget -qO- "https://deb.linuxmuster.net/pub.gpg" | gpg --dearmour -o /usr/share/keyrings/linuxmuster.net.gpg
```

### 2. Add repo

```bash
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/linuxmuster.net.gpg] https://deb.linuxmuster.net/ lmn73 main" > /etc/apt/sources.list.d/lmn73.list'
```

### 3. Update & install

```bash
sudo apt update && sudo apt install linuxmuster-fileserver
```

## Setup

1. Add fileserver to ```devices.csv``` and import the devices with ```linuxmuster-import-devices```. Example:
```csv
server;file01;nopxe;BC:24:11:4D:97:AB;10.0.0.101;;;;server;;0;;;;SETUP;
```

2. Setup the fileserver
```
linuxmuster-fileserver setup [-d DOMAIN] [-u USERNAME] [-p PASSWORD] [-s SCHOOL]
```
| Parameter | Description | Default |
|-----------|-------------|---------|
| -h        | Help-Page   |         |
| -d        | Domain of the AD | linuxmuster.lan |
| -u        | Username of an adminitrative user | global-admin |
| -p        | Password for the administrative user (will be asked if not specified) |  |
| -s        | Schoolname for the share (same as in AD) | default-school |

3. Update Share on Linuxmuster-Server
```
SCHOOL=default-school
FQDN=file01.linuxmuster.lan

# Create a new share, only necessary for new installation,
# but should be removed for migration
net conf addshare $SCHOOL /srv/samba/schools/$SCHOOL/

# Configure the share as a DFS share
net conf delparm $SCHOOL "guest ok"
net conf delparm $SCHOOL "read only"
net conf delparm $SCHOOL "path"
net conf setparm $SCHOOL "msdfs root"  yes
net conf setparm $SCHOOL "msdfs proxy"  //$FQDN/$SCHOOL
net conf setparm $SCHOOL "hide unreadable"  yes
```

⚠️ The FQDN must resolve to the file server's address. So, specify the same name as in the ```devices.csv```!

⚠️ The school must be the same as created on the file server!

⚠️ The first command `net conf addshare` should be removed if you are migrating an existing share to the fileserver!

4. Run ```sophomorix-repair --all``` on the Linuxmuster-Server

## Migration

It is possible to outsource an existing share to a file server. 
To do this: 
- install the file server as described above, but without the command `net conf addshare` in the last script,
- copy the files from ```/srv/samba/schools/default-school``` to the file server (for example, via rsync),
- set the permissions correctly, run ```sophomorix-repair --all``` on the linuxmuster.net's server after copying the files,
- run ```linuxmuster-fix-acls default-school``` on the file server to set the permissions recursively for all files and folders.

## Troubleshooting

- See if services running an fileserver ```linuxmuster-fileserver status```
- Check if users and groups can be read on the file server ```wbinfo -u``` and ```wbinfo -g```
- Check if clients can be reached on the file server

## How Samba DFS works

When a client accesses a DFS path (e.g., ```\\server\default-school```), Samba responds with a DFS referral. This referral tells the client where the actual data is stored — typically a UNC path like ```\\file01.linuxmuster.lan\default-school```.

The client then transparently connects to that target server and accesses the files directly, as if they were part of the original DFS path. The redirection happens behind the scenes, so users always see the unified DFS namespace.

Key points:

- Clients access a virtual root (\\domain\dfsroot) instead of individual servers.

- Samba redirects the client to the correct server using DFS referrals.

- After redirection, file access works just like with any regular SMB share.

## Performance improvement

### 📊 SMB Performance Comparison: file01 vs. server

As part of an internal benchmark, we evaluated the SMB performance of two shares:

    file01 – a dedicated file server

    server – a domain controller that also hosts file shares

### 🔧 Test Setup

We used the following command to upload and immediately delete a 1 GB test file (http://speedtest.belwue.net/random-1G) in each run:

```bash
smbclient //<target>/<share> -U global-admin -k -c "put random-1G;rm random-1G"
```

    Each test was repeated 100 times

    The execution time was measured for every run

    Average times were calculated for both servers

### 📈 Average Results
| Target	| Avg. Time (Seconds) |
|-----------|---------------------|
| file01	| 2.102               |
| server	| 5.418               |

### 🚀 Relative Performance

    file01 is 61.2% faster than server

    server is 157.7% slower than file01

### 🧠 Summary

A dedicated file server (file01) not only improves system architecture by separating concerns, but also provides significantly better performance in real-world SMB file operations.

This result reinforces the recommendation to avoid using domain controllers for file storage in performance-sensitive environments. A standalone file server improves throughput, reduces latency, and simplifies resource scaling.
