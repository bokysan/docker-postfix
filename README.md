# docker-postfix
Simple postfix relay host for your Docker containers. Based on Alpine Linux.


## Project update

**Notice, that while this commits are old, there project is not dead.** It's simply considered feature complete. You will find the latest version of the code on Dockerhub (https://hub.docker.com/r/boky/postfix). If you do have any suggestions, feel free to clone and post a merge.

## Description

This image allows you to run POSTFIX internally inside your docker cloud/swarm installation to centralise outgoing email sending. The embedded postfix enables you to either _send messages directly_ or _relay them to your company's main server_.

This is a _server side_ POSTFIX image, geared towards emails that need to be sent from your applications. That's why this postfix configuration does not support username / password login or similar client-side security features.

**IF YOU WANT TO SET UP AND MANAGE A POSTFIX INSTALLATION FOR END USERS, THIS IMAGE IS NOT FOR YOU.** If you need it to manage your application's outgoing queue, read on.

## TL;DR

To run the container, do the following:
```
docker run --rm --name postfix -p 1587:587 boky/postfix
```

You can now send emails by using `localhost:1587` as your SMTP server address. **Please note that
the image uses the submission (587) port by default**. Port 25 is not exposed on purpose, as it's
regularly blocked by ISP or already occupied by other services.

All standard caveats of configuring the SMTP server apply -- e.g. you'll need to make sure your DNS
entries are updated properly if you don't want your emails marked as spam.

## Configuration options

The following configuration options are available:
```
ENV vars
$HOSTNAME = Postfix myhostname
$RELAYHOST = Host that relays your msgs
$RELAYHOST_USERNAME = An (optional) username for the relay server
$RELAYHOST_PASSWORD = An (optional) login password for the relay server
$MYNETWORKS = allow domains from per Network ( default 127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 )
$ALLOWED_SENDER_DOMAINS = domains sender domains
```
### `HOSTNAME`

You may configure a specific hostname that the SMTP server will use to identify itself. If you don't do it,
the default Docker host name will be used. A lot of times, this will be just the container id (e.g. `f73792d540a5`)
which may make it difficult to track your emails in the log files. If you care about tracking at all,
I suggest you set this variable, e.g.:
```
docker run --rm --name postfix -e HOSTNAME=postfix-docker -p 1587:587 boky/postfix
```

### `RELAYHOST`, `RELAYHOST_USERNAME` and `RELAYHOST_PASSWORD`

Postfix will try to deliver emails directly to the target server. If you are behind a firewall, or inside a corporation
you will most likely have a dedicated outgoing mail server. By setting this option, you will instruct postfix to relay
(hence the name) all incoming emails to the target server for actual delivery.

Example:
```
docker run --rm --name postfix -e RELAYHOST=192.168.115.215 -p 1587:587 boky/postfix
```

You may optionally specifiy a relay port, e.g.:
```
docker run --rm --name postfix -e RELAYHOST=192.168.115.215:587 -p 1587:587 boky/postfix
```

Or an IPv6 address, e.g.:
```
docker run --rm --name postfix -e 'RELAYHOST=[2001:db8::1]:587' -p 1587:587 boky/postfix
```

If your end server requires you to authenticate with username/password, add them also:
```
docker run --rm --name postfix -e RELAYHOST=mail.google.com -e RELAYHOST_USERNAME=hello@gmail.com -e RELAYHOST_PASSWORD=world -p 1587:587 boky/postfix
```

## `RELAYHOST_USE_TLS`

If your relayhost uses TLS set this to 'yes' to turn on TLS for postfix

### `POSTFIX_EXTRAS_SETTINGS`

Any additional settings can be passed directly to config here, for example: POSTFIX_EXTRAS_SETTINGS=smtp_use_tls=yes smtp_enforce_tls=yes

### `MYNETWORKS`

This implementation is meant for private installations -- so that when you configure your services using _docker compose_
you can just plug it in. Precisely because of this reason and the prevent any issues with this postfix being inadvertently
exposed on the internet and then used for sending spam, the *default networks are reserved for private IPv4 IPs only*.

Most likely you won't need to change this. However, if you need to support IPv6 or strenghten the access further, you can
override this setting.

Example:
```
docker run --rm --name postfix -e "MYNETWORKS=10.1.2.0/24" -p 1587:587 boky/postfix
```

### `ALLOWED_SENDER_DOMAINS`

If your application is sending email from just a few domains (and most application do), it is a good practice to lock the
POSTFIX further down and accept email from these domains only.

Example:
```
docker run --rm --name postfix -e "ALLOWED_SENDER_DOMAINS=example.com example.org" -p 1587:587 boky/postfix
```

## Extending the image

If you need to add custom configuration to postfix or have it do something outside of the scope of this configuration, simply
add your scripts to `/docker-init.db/`. All files with the `.sh` extension will be executed automatically at the end of the
startup script.

E.g.: create a custom `Dockerfile` like this:
```
FROM boky/postfix
MAINTAINER Some Randombloke "randombloke@example.com"
ADD Dockerfiles/additional-config.sh /docker-init.db/
```

Build it with docker and your script will be automatically executed before Postfix starts.

## Security

Postfix will run the master proces as `root`, because that's how it's designed. Subprocesses will run under the `postfix` account
which will use `UID:GID` of `100:101`.
