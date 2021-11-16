# SYSJACK
SYSJACK is an aid to simplify installation and maintenance of a JACK daemon for devices to which it is assumed that haven't access
to terminal or GUI.

I am carrying out a project for a headless synth with raspbery pi 3 and 4, and I'm using a modular approach to better manage and share mine
work. SYSJACK is one of these modules.

SYSJACK locates the sound cards available with ALSA, allows you to choose and set your configuration, and then save it to a .json file,
so you can reuse JACK's settings with other applications.

As a bonus, SYSJACK can create other systemd services, which can be really useful if you are planning to do a simple synth, i.e. a single
process running on JACK.

Benefits of this approach are:
- all systemd benefits including restart on crash;
- hierarchy: run other stuff only after JACKD is started;
- configurable: sometimes you have to change parameters over and over to get the right configuration. Some other times you need to know certain parameters. This helped me a lot in checking out the right configuration for my headless pi.

## Requirements

You need a Linux OS with a **low latency kernel**. To find out if yours kernels are realtime, write:

```
uname -a
```

if PREEMPT is present in the name of your operating system, you have
low latency kernels. Otherwise [here is a guide to generating them] (#https: //github.com/dddomin3/DSPi).

You will need ALSA drivers (always present)  and JACKD2, which you can get by simply writing

```
sudo apt-get install --no-recommends jackd2
```

jackd2 should be preferred to jackd1 as it should have a fix with the infamous d-bus error. SYSJACK does take care of that too.

- An **external sound card** is recommended since pi's internal audio card is hardly capable of handling realtime audio, as it works
with an intermediate buffer. I never managed to run jackd succesfully with the builtin audio card.
- You will also need **perl** installed ```sudo apt-get install perl```.
- Finally, unless you have a way for downloading this, you will probably need ```sudo apt-get install git``` to clone this repository.

## Alsacap
ALSACAP is a small piece of code by Volker Schatz. Source code is included here as it is not easy to find. It will enumerate
any audio device capability, including sample rate and sample format. You may need tools such as __make__ and __autotools__ to
compile it. It is not necessary but useful.

## PERL
Perl is a common, if not ancient, script language. You don't need to know anything perl, just to install it
```
sudo apt-get install perl libjson-perl
```
This will also install the JSON library needed to read/write configs.

# Installation

1. First, clone this repository. ```git clone https://github.com/StefanoMarina/sysjack.git sysjack```;
2. Enable execution of perl files ```sudo chmod +x *.pl```;
3. Let's configure SYSJACK! do ```./configure.pl``` to start the process and follow the instructions.
4. Now that a config.json file was made, run ```./install.pl jackd``` to create a jackd.service. Press 'i' when asked to install or local, to install it on system directory.
5. Done!

# Details

## configure.pl
configure.pl will accept the following syntax: _.configure.pl (config=configfile) (key=jsonkey)_

- config: you can specify the json file to write.
- key: this setting tells configure that the json file is not all about sysjack. configure will search the matching _key_ and write there all his setting, preserving other stuff. This is useful if you are using a single, large json file for configuration.

### Alsa and backups
configure.pl will ask you if you want to create an /etc/asound.conf file. This file will set your selected audio card as ALSA default audio card, and will create an alias for SYSJACK alsa device called SYSJACK, so you can use i.e. ```aplay -D SYSJACK``` if you don't want to change your default audio card.

Any major file change is always backupped in home directory/.sysjack as a .backup file.

## install.pl
install.pl accepts this sintax: _./install.pl unit-name (config=configfile) (key=jsonkey) (-y)_.

coonfig and key are the same value as configure.pl.

The -y(es) flag will skip the install/local question and just install the required service.



# Changing / adding services

## Configuration
SYSJACK works on a simple string replacement method. the json file has 3 categories: 
- **card** containing all card info;
- **jack** containing jackd params;
- **user** contaning misc stuff

here is a simple .json
```json
{
   "card" : {
      "card_id" : "1",
      "samplerate" : "48000",
      "card_longname" : "USB Audio CODEC",
      "alsa_id" : "hw:1,0",
      "device_name" : "USB Audio ",
      "device_id" : "0",
      "card_shortname" : "CODEC"
   },
   "units" : {
      "jackd" : "/usr/bin/jackd -R -p{jack/ports} -t{jack/timeout} -d alsa -d{card/alsa_id} -{jack/alsa_mode} -p {jack/buffersize} -n {jack/alsa_periods} -r {card/samplerate} -s"
   },
   "user" : {
      "sub_priority" : "80"
   },
   "jack" : {
      "alsa_periods" : "2",
      "buffersize" : 512,
      "timeout" : "2000",
      "alsa_mode" : "P",
      "ports" : 16,
      "priority" : "80"
   }
}
```
The **units** property contains  key/value pairs for processes. Values are strings containing {stuff inside curly brackets}.

When installing, SYSJACK will simply replace the content from the brackets with the value inside the parameter.

So, if you want to pass the alsa HW id as a parameter, you just write {card/alsa_id}. SYSJACK will look for the alsa_id value inside the _card_ property.

## Adding services and stuff

You may add everything everywhere, but keep in mind that launching ./configure.pl again will _cleanse_ all your customization. If the _key_ parameter is specified, everything outside the key will be preserverd. Backup! always backup!

To add a service, add a new entry in units, use the name you want for a service, then pass the parameter string as value:
**remeber that systemd requires absolute paths only!**

```
...
"units": {
  "mynewunit": "/usr/bin/myunitexe unit parameters"
}
...
```

### Cookbook: zynaddsubfx

Let's say you want zynaddsubfx, the famous open source synth, to automatically start _after_ JACKD. You also want to make it OSC responsive, so you need to have the
port as a property that can be read elsewhere.

Let's open config.json and add this bit under the 'user' property:

```json
"user" : {
   "zyn_OSC": "7777"
   "sub_priority": "80",
}
```
now let's write the unit, add this bit under "units", just before "jackd":
```json
"units" : {
   "zynasfx": "/usr/local/bin/zynaddsubfx -U -A=0 -I JACK -O JACK -o 256 -b {jack/buffersize} -r {card/samplerate} -P {user/zyn_OSC}",
   "jackd" : "/usr/bin/jackd -R -p{jack/ports} -t{jack/timeout} -d alsa -d{card/alsa_id} -{jack/alsa_mode} -p {jack/buffersize} -n {jack/alsa_periods} -r {card/samplerate} -s"
}
```

run ```./install.pl zynasfx``` and press (l) when asked to install. this will create a .service file inside SYSJACK directory. check it out - if the file is correct, run install.pl with the -y flag to install the service.

## Further customization
Let's say you need to customize you service but you don't want to change it everytime.

```cp src/default.service.in src/myservice.service.in``` where _myservice_ is your unit name (i.e. zynasfx.service.in). This will tell install.pl to use a customized template when recustomizing services.

