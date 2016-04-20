archiso-ssh-remix
=================

This is a tool to remaster the Arch Linux installation ISO image. It
adds the following stuff:

 * 5s bootloader timeout to boot unattended without having to
   press Enter.
 * OpenSSH installed and sshd service started on boot.
 * Your personal SSH pubkeys burned into the iso image so you can
   login remotely.
 * Your personal WiFi passwords burned into the iso image, and
   configures WiFi on boot. (This is currently a bit flaky, wired
   works fine)
 * avahi-daemon publishes the availability of a service called
   'archiso', this lets you scan for the machine on your network
   without having to know the IP address.

What is this useful for?
------------------------

The regular Arch iso doesn't have an SSH server, nor does it
automatically setup wifi - you need to plug in a keyboard and monitor
to use it. I find this inconvenient. 

This tool is useful for when you want to install Arch Linux on a
remote computer without needing a keyboard/mouse. You connect remotely
via SSH instead. This will create an iso that contains your personal
SSH public keys as well as your WiFi passwords. So this is a
*personalized* Arch Linux installer CD.

How to remix your own arch iso
------------------------------

Clone this repository:

    git clone https://github.com/EnigmaCurry/archiso-ssh-remix.git
	
In the archiso-ssh-remix directory you will find the `build-iso.sh`
script as well as a directory called `demo`. Taking a look inside the
`demo` directory first you will find two asset files:

 * `authorized_keys` - This is the file that should contain all your
   SSH public keys that will be allowed to connect to the archiso
   host. The key you want to copy to this file is usually contained in
   `~/.ssh/id_rsa.pub`
 * `wpa_supplicant.conf` - This is the file that should contain all
   your WiFi SSID and password information. There are some examples in
   the demo version of this file, but also check out `man
   wpa_supplicant.conf`
   
The demo directory is just that, a demo. You should create your own
directory (call it whatever you like) with your own configuration
files.

Now run the `build-iso.sh` script to build your iso:

    ./build-iso.sh -i ~/Downloads/archlinux-2016.04.01-dual.iso -o arch-2016-04-01-ssh-remix.iso demo
	
Replace the `-i` parameter with the path to the original Arch Linux
installer iso file. Replace the `-o` parameter with whatever you want
to call your new iso image. Replace `demo` with the name of the
directory you created.


Using the ISO
-------------

To transfer the ISO image to a USB drive (eg. /dev/sdb) (Careful, make
sure you use the right device name as this will wipe the drive!):

    sudo dd if=your-remastered.iso of=/dev/sdb bs=100M
	
Before you boot up the computer with the USB drive, run the `scan.sh`
tool on another computer in your same network. It won't output
anything at first, but once the machine you're installing on is
finished booting, you should see the IP address printed out. This is
useful since the Arch iso gets an IP address via DHCP and you wouldn't
otherwise know what address to connect to.

`scan.sh` requires avahi-daemon, so if you don't have that yet install it:

    pacman -S avahi-daemon dbus
	systemctl enable avahi
	systemctl enable dbus
	systemctl start dbus
	systemctl start avahi

Once the machine is booted, and you know it's IP address, you can ssh
to it. The server's SSH keys change everytime the iso boots, so it
doesn't make any sense to store the keys, the following ssh command
will disable it for the session:

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@ip_address

Alternatively, depending on how your LAN DNS is setup, you may find
that the name `archiso` automatically resolves to the machine as it
boots up. If that's the case, you don't need the scan tool (although
still useful to tell when it's up), and you could put the following
into your `~/.ssh/config`:

    Host archiso
	  User root
      StrictHostKeyChecking no
      UserKnownHostsFile=/dev/null

Then all that would be necessary is to run:

    ssh archiso

You should be able to login without any password assuming you have the
same SSH key setup locally as you have burned into the iso image.
