# docker-postfix

![Build status](https://github.com/bokysan/docker-postfix/workflows/Docker%20image/badge.svg) [![Latest commit](https://img.shields.io/github/last-commit/bokysan/docker-postfix)](https://github.com/bokysan/docker-postfix/commits/master) [![Latest release](https://img.shields.io/github/v/release/bokysan/docker-postfix?sort=semver&Label=Latest%20release)](https://github.com/bokysan/docker-postfix/releases) [![Docker image size](https://img.shields.io/docker/image-size/boky/postfix?sort=semver)](https://hub.docker.com/r/boky/postfix/) ![GitHub Repo stars](https://img.shields.io/github/stars/bokysan/docker-postfix?label=GitHub%20Stars&style=flat) [![Docker Stars](https://img.shields.io/docker/stars/boky/postfix.svg?label=Docker%20Stars)](https://hub.docker.com/r/boky/postfix/) [![Docker Pulls](https://img.shields.io/docker/pulls/boky/postfix.svg)](https://hub.docker.com/r/boky/postfix/) ![License](https://img.shields.io/github/license/bokysan/docker-postfix) [![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fbokysan%2Fdocker-postfix.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Fbokysan%2Fdocker-postfix?ref=badge_shield)

Simple postfix relay host ("postfix null client") for your Docker containers. Based on Debian (default), Ubuntu and Alpine Linux. 
Feel free to pick your favourite distro.

## Table of contents

- [docker-postfix](#docker-postfix)
  - [Table of contents](#table-of-contents)
  - [Description](#description)
  - [TL;DR](#tldr)
  - [Updates](#updates)
    - [v4.0.0](#v400)
    - [v3.0.0](#v300)
  - [Architectures](#architectures)
  - [Configuration options](#configuration-options)
    - [General options](#general-options)
      - [Inbound debugging](#inbound-debugging)
      - [`ALLOWED_SENDER_DOMAINS` and `ALLOW_EMPTY_SENDER_DOMAINS`](#allowed_sender_domains-and-allow_empty_sender_domains)
      - [`AUTOSET_HOSTNAME` and `AUTOSET_HOSTNAME_SERVICES`](#autoset_hostname-and-autoset_hostname_services)
      - [Log format](#log-format)
    - [Postfix-specific options](#postfix-specific-options)
      - [`RELAYHOST`, `RELAYHOST_USERNAME` and `RELAYHOST_PASSWORD`](#relayhost-relayhost_username-and-relayhost_password)
      - [`POSTFIX_smtp_tls_security_level`](#postfix_smtp_tls_security_level)
      - [`XOAUTH2_CLIENT_ID`, `XOAUTH2_SECRET`, `XOAUTH2_INITIAL_ACCESS_TOKEN`, `XOAUTH2_INITIAL_REFRESH_TOKEN` and `XOAUTH2_TOKEN_ENDPOINT`](#xoauth2_client_id-xoauth2_secret-xoauth2_initial_access_token-xoauth2_initial_refresh_token-and-xoauth2_token_endpoint)
        - [OAuth2 Client Credentials (GMail)](#oauth2-client-credentials-gmail)
        - [Obtain Initial Access Token (GMail)](#obtain-initial-access-token-gmail)
        - [Debug XOAuth2 issues](#debug-xoauth2-issues)
      - [`MASQUERADED_DOMAINS`](#masqueraded_domains)
      - [`SMTP_HEADER_CHECKS`](#smtp_header_checks)
      - [`POSTFIX_myhostname`](#postfix_myhostname)
      - [`POSTFIX_mynetworks`](#postfix_mynetworks)
      - [`POSTFIX_message_size_limit`](#postfix_message_size_limit)
      - [Overriding specific postfix settings](#overriding-specific-postfix-settings)
      - [`SKIP_ROOT_SPOOL_CHOWN`](#skip_root_spool_chown)
      - [`ANONYMIZE_EMAILS`](#anonymize_emails)
        - [The `default` (`smart`) filter](#the-default-smart-filter)
        - [The `paranoid` filter](#the-paranoid-filter)
        - [The `hash` filter](#the-hash-filter)
        - [The `noop` filter](#the-noop-filter)
        - [Writing your own filters](#writing-your-own-filters)
    - [DKIM / DomainKeys](#dkim--domainkeys)
      - [Supplying your own DKIM keys](#supplying-your-own-dkim-keys)
      - [Auto-generating the DKIM selectors through the image](#auto-generating-the-dkim-selectors-through-the-image)
      - [Changing the DKIM selector](#changing-the-dkim-selector)
      - [Overriding specific OpenDKIM settings](#overriding-specific-opendkim-settings)
      - [Verifying your DKIM setup](#verifying-your-dkim-setup)
    - [Docker Secrets / Kubernetes secrets](#docker-secrets--kubernetes-secrets)
  - [Helm chart](#helm-chart)
    - [Metrics](#metrics)
  - [Extending the image](#extending-the-image)
    - [Using custom init scripts](#using-custom-init-scripts)
  - [Security](#security)
    - [UIDs/GIDs numbers](#uidsgids-numbers)
  - [Quick how-tos](#quick-how-tos)
    - [Relaying messages through your Gmail account](#relaying-messages-through-your-gmail-account)
    - [Relaying messages through Google Apps account](#relaying-messages-through-google-apps-account)
    - [Relaying messages through Amazon's SES](#relaying-messages-through-amazons-ses)
    - [Sending messages directly](#sending-messages-directly)
      - [Careful](#careful)
  - [Similar projects](#similar-projects)
  - [License check](#license-check)

## Description

This image allows you to run POSTFIX internally inside your docker cloud/swarm installation to centralise outgoing email
sending. The embedded postfix enables you to either _send messages directly_ or _relay them to your company's main
server_.

This is a _server side_ POSTFIX image, geared towards emails that need to be sent from your applications. That's why
this postfix configuration does not support username / password login or similar client-side security features.

**IF YOU WANT TO SET UP AND MANAGE A POSTFIX INSTALLATION FOR END USERS, THIS IMAGE IS NOT FOR YOU.** If you need it to
manage your application's outgoing queue, read on.

## TL;DR

To run the container, do the following:

```shell script
docker run --rm --name postfix -e "ALLOWED_SENDER_DOMAINS=example.com" -p 1587:587 boky/postfix
```

or

```shell script
helm repo add bokysan https://bokysan.github.io/docker-postfix/
helm upgrade --install --set persistence.enabled=false --set config.general.ALLOW_EMPTY_SENDER_DOMAINS=yes mail bokysan/mail
```

You can also find this image at [ArtifactHub](https://artifacthub.io/packages/helm/docker-postfix/mail).


You can now send emails by using `localhost:1587` (on Docker) as your SMTP server address. Note that if you haven't configured your domain
to allow sending from this IP/server/nameblock, **your emails will most likely be regarded as spam.**

All standard caveats of configuring the SMTP server apply:

- **MAKE SURE YOUR OUTGOING PORT 25 IS NOT BLOCKED.**
  - Most ISPs block outgoing connections to port 25 and several companies (e.g.
    [NoIP](https://www.noip.com/blog/2013/03/26/my-isp-blocks-smtp-port-25-can-i-still-host-a-mail-server/),
    [Dynu](https://www.dynu.com/en-US/Blog/Article?Article=How-to-host-email-server-if-ISP-blocks-port-25)) offer
    workarounds.
  - Hosting centers also tend to block port 25, which can be unblocked per request, see below for AWS hosting.
- You'll most likely need to at least [set up SPF records](https://en.wikipedia.org/wiki/Sender_Policy_Framework)
  (see also [openspf](http://www.open-spf.org/)) and/or [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail).
- If using DKIM ([below](#dkim--domainkeys)), make sure to add DKIM keys to your domain's DNS entries.
- You'll most likely need to set up [PTR](https://en.wikipedia.org/wiki/Reverse_DNS_lookup) records as well to prevent your
  mails going to spam.

If you don't know what any of the above means, get some help. Google is your friend. It's also worth noting that it's pretty difficult
to host a SMTP server on a dynamic IP address.

**Please note that the image uses the submission (587) port by default**. Port 25 is not exposed on purpose, as it's regularly blocked
by ISPs, already occupied by other services, and in general should only be used for server-to-server communication.

## Updates

### v4.0.0

Several potentially "surprising" changes went into this issue and hence warrant a version upgrade:

- **Default image is now based on Debian.** A lot of packages needed for
  latest builds are missing in certain Alpine architectures. Debian
  allows us to have a greater cross-platform availability.
- **Helm charts are now built with `v` and without `v` prefix.**
  As seen in [PR #141](https://github.com/bokysan/docker-postfix/pull/141) some tools rely on version not
  having the prefix. I've seen both in the wild, so the image
  now includes both. This should work and should hopefully provide most compatibility.
- **[`master`](https://github.com/bokysan/docker-postfix/tree/master/) branch now builds images called [`edge`](https://hub.docker.com/r/boky/postfix/tags?page=1&name=edge)**. 
  `latest` images are built from the last tag. We've had several issues with people using the `latest` tag
  and reporting problems. You can now rely on `latest` being the latest stable release.
- Image now builds its own version of [postfix-exporter](https://github.com/kumina/postfix_exporter) and relies on this
  third-party project. Checkout is from master branch, based
  on specific SHA commit id. The same hash is used for master and tags.
- **Architecture galore!** With the addition of debian images, we now support support more architectures than ever. The list includes: 
  `linux/386`, `linux/amd64`, `linux/arm/v5`, `linux/arm/v6`, `linux/arm/v7`, `linux/arm64`, `linux/arm64/v8`, `linux/mips64le`, 
  `linux/ppc64le` and `linux/s390x`.
- **`smtpd_tls_security_level` is now set to `may`**. If you encounter
  issues, try setting it to `none` explicitly (see [#160](https://github.com/bokysan/docker-postfix/issues/160)).

### v3.0.0

There's a potentially breaking change introduced now in `v3.0.0`: Oracle has changed the license of BerkleyDB to AGPL-3.0, making it
unsuitable to link to packages with GPL-incompatible licenses. As a result Alpine (on which this image is based)
[has deprecated BerkleyDB throughout the image](https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.13.0#Deprecation_of_Berkeley_DB_.28BDB.29):

> Support for Postfix `hash` and `btree` databases has been removed. `lmdb` is the recommended replacement. Before upgrading, all tables in
> `/etc/postfix/main.cf` using `hash` and `btree` must be changed to a supported alternative. See the
> [Postfix lookup table documentation](http://www.postfix.org/DATABASE_README.html) for more information.

While this should not affect most of the users (`/etc/postfix/main.cf` is managed by this image), there might be use cases where
people have their own configuration which relies on `hash` and `btree` databases. To avoid braking live systems, the version of this
image has been updated to `v3.0.0`.

## Architectures

Available for all your favourite architectures. Run in your server cluster. Run it on your Raspberry Pi 4. Run it on your ancient Pentium or an old Beaglebone. The following architectures are supported: `linux/386`, `linux/amd64`, `linux/arm/v6`, `linux/arm/v7`, `linux/arm64` and `linux/ppc64le`.

## Configuration options

### General options

* `TZ` = The timezone for the image, e.g. `Europe/Amsterdam`
* `FORCE_COLOR` = Set to `1` to force color output (otherwise auto-detected)
* `INBOUND_DEBUGGING` = Set to `1` to enable detailed debugging in the logs
* `ALLOWED_SENDER_DOMAINS` = domains which are allowed to send email via this server
* `ALLOW_EMPTY_SENDER_DOMAINS` = if value is set (i.e: `true`), `ALLOWED_SENDER_DOMAINS` can be unset
* `AUTOSET_HOSTNAME` and `AUTOSET_HOSTNAME_SERVICES` - use to automatically resolve hostname
* `LOG_FORMAT` = Set your log format (JSON or plain)

#### Inbound debugging

Enable additional debugging for any connection coming from `POSTFIX_mynetworks`. Set to a non-empty string (usually `1`
or  `yes`) to enable debugging.

#### `ALLOWED_SENDER_DOMAINS` and `ALLOW_EMPTY_SENDER_DOMAINS`

Due to in-built spam protection in [Postfix](http://www.postfix.org/postconf.5.html#smtpd_relay_restrictions) you will
need to specify sender domains -- the domains you are using to send your emails from, otherwise Postfix will refuse to
start.

Example:

```shell script
docker run --rm --name postfix -e "ALLOWED_SENDER_DOMAINS=example.com example.org" -p 1587:587 boky/postfix
```

If you want to set the restrictions on the recipient and not on the sender (anyone can send mails but just to a single domain
for instance), set `ALLOW_EMPTY_SENDER_DOMAINS` to a non-empty value (e.g. `true`) and `ALLOWED_SENDER_DOMAINS` to an empty
string. Then extend this image through custom scripts to configure Postfix further.

#### `AUTOSET_HOSTNAME` and `AUTOSET_HOSTNAME_SERVICES`

This image can automatically set  postfix variable `myhostname` based on reverse DNS resolution of your public IP. To use this
feature, set `AUTOSET_HOSTNAME` to `1`. The image will then:

- use an external service to get the public IP address of the image
- do a reverse DNS lookup to get the hostname associated with that IP

The image will, by default, try to get the public IP from any of these services, which will be queried in the order defined below:

1. https://ipinfo.io/ip
2. https://ifconfig.me/ip
3. https://icanhazip.com
4. https://ipecho.net/plain
5. https://ifconfig.co
6. https://myexternalip.com/raw

The first service to return a non-empty, non-error response will be deemed successful. If you have a preference of another order
and/or wish to use a different service, you can do that by setting the bash array `AUTOSET_HOSTNAME_SERVICES`.

#### Log format

The image will by default output logs in human-readable (`plain`) format. If you are deploying the image to Kubernetes, it might
be worth changing the output format to `json` as it's more easily parsable by tools such as [Prometheus](https://prometheus.io/).

To change the log format, set the (unsurprisingly named) variable `LOG_FORMAT=json`.

### Postfix-specific options

- `RELAYHOST` = Host that relays your messages
- `SASL_RELAYHOST` = (optional) Relay Host referenced in the `sasl_passwd` file. Defaults to the value of `RELAYHOST`
- `RELAYHOST_USERNAME` = An (optional) username for the relay server
- `RELAYHOST_PASSWORD` = An (optional) login password for the relay server
- `RELAYHOST_PASSWORD_FILE` = An (optional) file containing the login password for the relay server. Mutually exclusive with the previous option.
- `POSTFIX_smtp_tls_security_level` = Relay host TLS connection level
- `XOAUTH2_CLIENT_ID` = OAuth2 client id used when configured as a relayhost.
- `XOAUTH2_SECRET` = OAuth2 secret used when configured as a relayhost.
- `XOAUTH2_INITIAL_ACCESS_TOKEN` = Initial OAuth2 access token.
- `XOAUTH2_INITIAL_REFRESH_TOKEN` = Initial OAuth2 refresh token.
- `XOAUTH2_TOKEN_ENDPOINT` = Token endpoint provided four your XOAUTH App , GMail use : https://accounts.google.com/o/oauth2/token
- `SMTPD_SASL_USERS` = Users allow to send mail (ex: user1:pass1,user2:pass2,...). *Warning:* Users need to be specified with a domain, as explained
  on ticket [[#192](https://github.com/bokysan/docker-postfix/issues/192)]. This image will automatically add a domain if one is not provided and will
  issue a notice when that happens.
- `MASQUERADED_DOMAINS` = domains where you want to masquerade internal hosts
- `SMTP_HEADER_CHECKS`= Set to `1` to enable header checks of to a location of the file for header checks
- `POSTFIX_myhostname` = Set the name of this postfix server
- `POSTFIX_mynetworks` = Allow sending mails only from specific networks ( default `127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` )
- `POSTFIX_message_size_limit` = The maximum size of the message, in bytes, by default it's unlimited
- `POSTFIX_<any_postfix_setting>` = provide any additional postfix setting

#### `RELAYHOST`, `RELAYHOST_USERNAME` and `RELAYHOST_PASSWORD`

Postfix will try to deliver emails directly to the target server. If you are behind a firewall, or inside a corporation
you will most likely have a dedicated outgoing mail server. By setting this option, you will instruct postfix to relay
(hence the name) all incoming emails to the target server for actual delivery.

Example:

```shell script
docker run --rm --name postfix -e RELAYHOST=192.168.115.215 -p 1587:587 boky/postfix
```

You may optionally specifiy a relay port, e.g.:

```shell script
docker run --rm --name postfix -e RELAYHOST=192.168.115.215:587 -p 1587:587 boky/postfix
```

Or an IPv6 address, e.g.:

```shell script
docker run --rm --name postfix -e 'RELAYHOST=[2001:db8::1]:587' -p 1587:587 boky/postfix
```

If your end server requires you to authenticate with username/password, add them also:

```shell script
docker run --rm --name postfix -e RELAYHOST=mail.google.com -e RELAYHOST_USERNAME=hello@gmail.com -e RELAYHOST_PASSWORD=world -p 1587:587 boky/postfix
```

#### `POSTFIX_smtp_tls_security_level`

Define relay host TLS connection level. See [smtp_tls_security_level](http://www.postfix.org/postconf.5.html#smtp_tls_security_level) for details. By default, the permissive level ("may") is used, which basically means "use TLS if available" and should be a sane default in most cases.

This level defines how the postfix will connect to your upstream server.

#### `XOAUTH2_CLIENT_ID`, `XOAUTH2_SECRET`, `XOAUTH2_INITIAL_ACCESS_TOKEN`, `XOAUTH2_INITIAL_REFRESH_TOKEN` and `XOAUTH2_TOKEN_ENDPOINT`

> Note: These parameters are used when `RELAYHOST` and `RELAYHOST_USERNAME` are provided.

These parameters allow you to configure a relayhost that requires (or recommends) the [XOAuth2 authentication method](https://github.com/tarickb/sasl-xoauth2) (e.g. GMail).

- `XOAUTH2_CLIENT_ID` and  `XOAUTH2_SECRET` are the [OAuth2 client credentials](#oauth2-client-credentials-gmail).
- `XOAUTH2_INITIAL_ACCESS_TOKEN` and `XOAUTH2_INITIAL_REFRESH_TOKEN` are the [initial access token and refresh tokens](#obtain-initial-access-token-gmail).
- `XOAUTH2_TOKEN_ENDPOINT` is mandatory for Microsoft 365 use, sasl-xoauth2 will use Gmail URL if it is not provided.
   These values are only  required to initialize the token file `/var/spool/postfix/xoauth2-tokens/$RELAYHOST_USERNAME`.

Example:

```shell script
docker run --rm --name pruebas-postfix \
    -e RELAYHOST="[smtp.gmail.com]:587" \
    -e RELAYHOST_USERNAME="<put.your.account>@gmail.com" \
    -e POSTFIX_smtp_tls_security_level="encrypt" \
    -e XOAUTH2_CLIENT_ID="<put_your_oauth2_client_id>" \
    -e XOAUTH2_SECRET="<put_your_oauth2_secret>" \
    -e ALLOW_EMPTY_SENDER_DOMAINS="true" \
    -e XOAUTH2_INITIAL_ACCESS_TOKEN="<put_your_acess_token>" \
    -e XOAUTH2_INITIAL_REFRESH_TOKEN="<put_your_refresh_token>" \
    boky/postfix
```

Next sections describe how to obtain these values.

##### OAuth2 Client Credentials (GMail)

Visit the [Google API Console](https://console.developers.google.com/) to obtain OAuth 2 credentials (a client ID and client secret) for an "Installed application" application type.

Save the client ID and secret and use them to initialize `XOAUTH2_CLIENT_ID` and  `XOAUTH2_SECRET` respectively.

We'll also need these credentials in the next step.

##### Obtain Initial Access Token (GMail)

Use the [Gmail OAuth2 developer tools](https://github.com/google/gmail-oauth2-tools/) to obtain an OAuth token by following the [Creating and Authorizing an OAuth Token](https://github.com/google/gmail-oauth2-tools/wiki/OAuth2DotPyRunThrough#creating-and-authorizing-an-oauth-token) instructions.

Save the resulting tokens and use them to initialize `XOAUTH2_INITIAL_ACCESS_TOKEN` and `XOAUTH2_INITIAL_REFRESH_TOKEN`.

##### Debug XOAuth2 issues

If you have XOAuth2 authentication issues you can enable XOAuth2 debug message setting `XOAUTH2_SYSLOG_ON_FAILURE` to `"yes"` (default: `"no"`). If you need a more detailed
log trace about XOAuth2 you can set `XOAUTH2_FULL_TRACE` to `"yes"` (default: `"no"`).

#### `MASQUERADED_DOMAINS`

If you don't want outbound mails to expose hostnames, you can use this variable to enable Postfix's
[address masquerading](http://www.postfix.org/ADDRESS_REWRITING_README.html#masquerade). This can be used to do things
like rewrite `lorem@ipsum.example.com` to `lorem@example.com`.

Example:

```shell script
docker run --rm --name postfix -e "ALLOWED_SENDER_DOMAINS=example.com example.org" -e "MASQUERADED_DOMAINS=example.com" -p 1587:587 boky/postfix
```

#### `SMTP_HEADER_CHECKS`

This image allows you to execute Postfix [header checks](http://www.postfix.org/header_checks.5.html). Header checks
allow you to execute a certain action when a certain MIME header is found. For example, header checks can be used
prevent attaching executable files to emails.

Header checks work by comparing each message header line to a pre-configured list of patterns. When a match is found the
corresponding action is executed. The default patterns that come with this image can be found in the `smtp_header_checks`
file. Feel free to override this file in any derived images or, alternately, provide your own in another directory.

Set `SMTP_HEADER_CHECKS` to type and location of the file to enable this feature. The sample file is uploaded into
`/etc/postfix/smtp_header_checks` in the image. As a convenience, setting `SMTP_HEADER_CHECKS=1` will set this to
`regexp:/etc/postfix/smtp_header_checks`.

Example:

```shell script
docker run --rm --name postfix -e "SMTP_HEADER_CHECKS="regexp:/etc/postfix/smtp_header_checks" -e "ALLOWED_SENDER_DOMAINS=example.com example.org" -p 1587:587 boky/postfix
```

#### `POSTFIX_myhostname`

You may configure a specific hostname that the SMTP server will use to identify itself. If you don't do it,
the default Docker host name will be used. A lot of times, this will be just the container id (e.g. `f73792d540a5`)
which may make it difficult to track your emails in the log files. If you care about tracking at all,
I suggest you set this variable, e.g.:

```shell script
docker run --rm --name postfix -e "POSTFIX_myhostname=postfix-docker" -p 1587:587 boky/postfix
```

#### `POSTFIX_mynetworks`

This implementation is meant for private installations -- so that when you configure your services using _docker compose_
you can just plug it in. Precisely because of this reason and the prevent any issues with this postfix being inadvertently
exposed on the internet and then used for sending spam, the *default networks are reserved for private IPv4 IPs only*.

Most likely you won't need to change this. However, if you need to support IPv6 or strenghten the access further, you
can override this setting.

Example:

```shell script
docker run --rm --name postfix -e "POSTFIX_mynetworks=10.1.2.0/24" -p 1587:587 boky/postfix
```

#### `POSTFIX_message_size_limit`

Define the maximum size of the message, in bytes.
See more in [Postfix documentation](http://www.postfix.org/postconf.5.html#message_size_limit).

By default, this limit is set to 0 (zero), which means unlimited. Why would you want to set this? Well, this is
especially useful in relation with `RELAYHOST` setting. If your relay host has a message limit (and usually it does),
set it also here. This will help you "fail fast" -- your message will be rejected at the time of sending instead having
it stuck in the outbound queue indefinitely.

#### Overriding specific postfix settings

Any Postfix [configuration option](http://www.postfix.org/postconf.5.html) can be overriden using `POSTFIX_<name>`
environment variables, e.g. `POSTFIX_allow_mail_to_commands=alias,forward,include`. Specifying no content (empty
variable) will remove that variable from postfix config.

#### `SKIP_ROOT_SPOOL_CHOWN`

Setting this to `1` will skip re-owning in `/var/spool/postfix/` and `/var/spool/postfix/pid`. You generally do not
want to set this option unless you're running into specific issues (e.g. [#97](https://github.com/bokysan/docker-postfix/issues/97)).

If unsure, leave it as is.

#### `ANONYMIZE_EMAILS`

Anonymize email in Postfix logs. It mask the email content by putting `*` in the middle of the name and the domain.
For example: `from=<a*****************s@a***********.com>`

Syntax: `<masker-name>[?option=value&option=value&....]`

**NOTICE:** Options are URL-encoded.

The following filters are provided with this implementation:

##### The `default` (`smart`) filter

Enable the filter by setting `ANONYMIZE_EMAILS=smart`.

The is enabled by setting the value to `on`, `true`, `1`, `default` or `smart`. The filter will take an educated guess at how to best mask the emails, specifically:

- It will leave the first and the last letter of the local part (if the local part is one letter long it gets repeated atht beggining and the end)
- If the local part is in quotes, it will remove the quotes (Warning: if the email starts with a space, this might look weird in logs)
- It will replace all the letters inbetween with **ONE** asterisk, even if there are none
- It will replace everything but a TLD with a star
- Address-style domains will see the number replaced with stars

E.g.:

- `demo@example.org` -> `d*o@*******.org`
- `john.doe@example.solutions` -> `j*e@*******.solutions`
- `sa@localhost` -> `s*a@*********`
- `s@[192.168.8.10]` -> `s*s@[*.*.*.*]`
- `"multi....dot"@[IPv6:2001:db8:85a3:8d3:1319:8a2e:370:7348]` -> `"m*t"@[IPv6:***********]`

Configuration parameters:

| Property         | Default value | Required | Description |
|------------------|---------------|----------|-------------|
| `mask_symbol`    | `*`           | no       | Mask symbol to use instead of replaced characters |

##### The `paranoid` filter

The paranoid filter works similar to smart filter but will:

- Replace the local part with **ONE** asterisk
- Replace the domain part (sans TLD) with **ONE** asterisk

E.g.:

- `demo@example.org` -> `*@*.org`
- `john.doe@example.solutions` -> `*@*.solutions`
- `sa@localhost` -> `*@*`
- `s@[192.168.8.10]` -> `*@[*]`
- `"multi....dot"@[IPv6:2001:db8:85a3:8d3:1319:8a2e:370:7348]` -> `*@[IPv6:*]`

Configuration parameters:

| Property         | Default value | Required | Description |
|------------------|---------------|----------|-------------|
| `mask_symbol`    | `*`           | no       | Mask symbol to use instead of replaced characters |

##### The `hash` filter

This filter will replace the email with the salted (HMAC - SHA256) hash. While it makes the logs much less readable, it has one specific benefit:
it allows you to search through the logs if you know the email address you're looking for. You are able to calculate the hash yourself
and then grep through the logs for this specific email address.

E.g.:

- `prettyandsimple@example.com` -> `<3052a860ddfde8b50e39843d8f1c9f591bec442823d97948b811d38779e2c757>` for (`ANONYMIZE_EMAILS=hash?salt=hello%20world`)
- `prettyandsimple@example.com` -> `c58731d3@8bd7a35c` for (`ANONYMIZE_EMAILS=hash?salt=hello%20world&split=true&short_sha=t&prefix=&suffix=`)

Filter will not work without configuration. You will need to provide (at least) the salt, e.g.: `ANONYMIZE_EMAILS=hash?salt=demo`

Configuration parameters:

| Property         | Default value | Required | Description |
|------------------|---------------|----------|-------------|
| `salt`           | none          | **yes**  | HMAC key (salt) used for calculating the checksum |
| `prefix`         | ``            | no       | Prefix of emails in the log (for easier grepping) |
| `suffix`         | ``            | no       | Suffix of emails in the log (for easier grepping) |
| `split`          | `false`       | no       | Set to `1`, `t` or `true` to hash separately the local and the domain part |
| `short_sha`      | `false`       | no       | Set to `1`, `t` or `true` to return just the first 8 characters of the hash |
| `case_sensitive` | `true`        | no       | Set to `0`, `f` or `false` to convert email to lowercase before hashing |

##### The `noop` filter

This filter doesn't do anything. It's used for testing purposes only.

##### Writing your own filters

It's easy enough to write your own filters. The simplest way would be to take the `email-anonymizer.py` file in this
image, write your own and then attach it to the container image under `/scripts`. If you're feeling adventureus, you can
also install your own Python package -- the script will automatically pick up the class name.

### DKIM / DomainKeys

**This image is equipped with support for DKIM.** If you want to use DKIM you will need to generate DKIM keys. These can
be either generated automatically, or you can supply them yourself.

The DKIM supports the following options:

- `DKIM_SELECTOR` = Override the default DKIM selector (by default "mail").
- `DKIM_AUTOGENERATE` = Set to non-empty value (e.g. `true` or `1`) to have the server auto-generate domain keys.
- `OPENDKIM_<any_dkim_setting>` = Provide any additional OpenDKIM setting.

#### Supplying your own DKIM keys

If you want to use your own DKIM keys, you'll need to create a folder for every domain you want to send through. You
will need to generate they key(s) with the `opendkim-genkey` command, e.g.

```shell script
mkdir -p /host/keys; cd /host/keys

for DOMAIN in example.com example.org; do
    # Generate a key with selector "mail"
    opendkim-genkey -b 2048 -h rsa-sha256 -r -v --subdomains -s mail -d $DOMAIN
    # Fixes https://github.com/linode/docs/pull/620
    sed -i 's/h=rsa-sha256/h=sha256/' mail.txt
    # Move to proper file
    mv mail.private $DOMAIN.private
    mv mail.txt $DOMAIN.txt
done
...
```

`opendkim-genkey` is usually in your favourite distribution provided by installing `opendkim-tools` or `opendkim-utils`.

Add the created `<domain>.txt` files to your DNS records. Afterwards, just mount `/etc/opendkim/keys` into your image
and DKIM will be used automatically, e.g.:

```shell script
docker run --rm --name postfix -e "ALLOWED_SENDER_DOMAINS=example.com example.org" -v /host/keys:/etc/opendkim/keys -p 1587:587 boky/postfix
```

#### Auto-generating the DKIM selectors through the image

If you set the environment variable `DKIM_AUTOGENERATE` to a non-empty value (e.g. `true` or `1`) the image will
automatically generate the keys.

**Be careful when using this option**. If you don't bind `/etc/opendkim/keys` to a persistent volume, you will get new
keys every single time. You will need to take the generated public part of the key (the one in the `.txt` file) and
copy it over to your DNS server manually.

#### Changing the DKIM selector

`mail` is the *default DKIM selector* and should be sufficient for most usages. If you wish to override the selector,
set the environment variable `DKIM_SELECTOR`, e.g. `... -e DKIM_SELECTOR=postfix`. Note that the same DKIM selector will
be applied to all found domains. To override a selector for a specific domain use the syntax
`[<domain>=<selector>,...]`, e.g.:

```shell script
DKIM_SELECTOR=foo,example.org=postfix,example.com=blah
```

This means:

- use `postfix` for `example.org` domain
- use `blah` for `example.com` domain
- use `foo` if no domain matches

#### Overriding specific OpenDKIM settings

Any OpenDKIM [configuration option](http://opendkim.org/opendkim.conf.5.html) can be overriden using `OPENDKIM_<name>`
environment variables, e.g. `OPENDKIM_RequireSafeKeys=yes`. Specifying no content (empty variable) will remove that
variable from OpenDKIM config.

#### Verifying your DKIM setup

I strongly suggest using a service such as [dkimvalidator](https://dkimvalidator.com/) to make sure your keys are set up
properly and your DNS server is serving them with the correct records.

### Docker Secrets / Kubernetes secrets

As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to some environment variables (see below), causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files. For example:

```
docker run --rm --name pruebas-postfix \
    -e RELAYHOST="[smtp.gmail.com]:587" \
    -e RELAYHOST_USERNAME="<put.your.account>@gmail.com" \
    -e POSTFIX_smtp_tls_security_level="encrypt" \
    -e XOAUTH2_CLIENT_ID_FILE="/run/secrets/xoauth2-client-id" \
    -e XOAUTH2_SECRET_FILE="/run/secrets/xoauth2-secret" \
    -e ALLOW_EMPTY_SENDER_DOMAINS="true" \
    -e XOAUTH2_INITIAL_ACCESS_TOKEN_FILE="/run/secrets/xoauth2-access-token" \
    -e XOAUTH2_INITIAL_REFRESH_TOKEN_FILE="/run/secrets/xoauth2-refresh-token" \
    boky/postfix
```

Currently, this is only supported for `RELAYHOST_PASSWORD`, `XOAUTH2_CLIENT_ID`, `XOAUTH2_SECRET`, `XOAUTH2_INITIAL_ACCESS_TOKEN`
and `XOAUTH2_INITIAL_REFRESH_TOKEN`.

## Helm chart

This image comes with its own helm chart. The chart versions are aligned with the releases of the image. Charts are hosted
through this repository.

To install the image, simply do the following:

```shell script
helm repo add bokysan https://bokysan.github.io/docker-postfix/
helm upgrade --install --set persistence.enabled=false --set config.general.ALLOWED_SENDER_DOMAINS=example.com mail bokysan/mail
```

Chart configuration is as follows:

| Property | Default value | Description |
|----------|---------------|-------------|
| `replicaCount` | `1` | How many replicas to start |
| `image.repository` | `boky/postfix` | This docker image repository |
| `image.tag` | *empty* | Docker image tag, by default uses Chart's `AppVersion` |
| `image.pullPolicy` | `IfNotPresent` | [Pull policy](https://kubernetes.io/docs/concepts/containers/images/#updating-images) for the image |
| `imagePullSecrets` | `[]` | Pull secrets, if neccessary |
| `nameOverride` | `""` | Override the helm chart name |
| `fullnameOverride` | `""` | Override the helm full deployment name |
| `serviceAccount.create` | `true` | Specifies whether a service account should be created |
| `serviceAccount.annotations` | `{}` | Annotations to add to the service account |
| `serviceAccount.name` | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| `service.type` | `ClusterIP` | How is the server exposed |
| `service.port` | `587` | SMTP submission port |
| `service.labels` | `{}` | Additional service labels |
| `service.annotations` | `{}` | Additional service annotations |
| `service.spec` | `{}` | Additional service specifications |
| `service.nodePort` | *empty* | Use a specific `nodePort` |
| `service.nodeIP` | *empty* | Use a specific `nodeIP` |
| `service.externalTrafficPolicy` | *empty* | Set `loadbalancer` [External traffic policy](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip) |
| `resources` | `{}` | [Pod resources](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) |
| `autoscaling.enabled` | `false` | Set to `true` to enable [Horisontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) |
| `autoscaling.minReplicas` | `1` | Minimum number of replicas |
| `autoscaling.maxReplicas` | `100` | Maximum number of replicas |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | When to scale up |
| `autoscaling.targetMemoryUtilizationPercentage` | `""` | When to scale up |
| `autoscaling.labels` | `{}` | Additional HPA labels |
| `autoscaling.annotations` | `{}` | Additional HPA annotations |
| `nodeSelector` | `{}` | Standard Kubernetes stuff |
| `tolerations` | `[]` | Standard Kubernetes stuff |
| `affinity` | `{}` | Standard Kubernetes stuff |
| `certs.create` | `false` | Auto generate TLS certificates for Postfix |
| `certs.existingSecret` | `""` | Existing secret containing the TLS certificates for Postfix |
| `extraVolumes` | `[]` | Append any extra volumes to the pod |
| `extraVolumeMounts` | `[]` | Append any extra volume mounts to the postfix container |
| `extraInitContainers` | `[]` | Execute any extra init containers on startup |
| `extraEnv` | `[]` | Add any extra environment variables to the container |
| `extraContainers` | `[]` | Add extra containers |
| `deployment.labels` | `{}` | Additional labels for the statefulset |
| `deployment.annotations` | `{}` | Additional annotations for the statefulset |
| `pod.securityContext` | `{}` | Pods's [security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| `pod.labels` | `{}` | Additional labels for the pod |
| `pod.annotations` | `{}` | Additional annotations for the pod |
| `container.postfix.securityContext` | `{}` | Containers's [security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| `config.general` | `{}` | Key-value list of general configuration options, e.g. `TZ: "Europe/London"` |
| `config.postfix` | `{}` | Key-value list of general postfix options, e.g. `myhostname: "demo"` |
| `config.opendkim` | `{}` | Key-value list of general OpenDKIM options, e.g. `RequireSafeKeys: "yes"` |
| `secret` | `{}` | Key-value list of environment variables to be shared with Postfix / OpenDKIM as secrets |
| `existingSecret` | `""` | A reference to an existing opaque secret. Secret is mounted and exposed as environment variables in the pod |
| `mountSecret.enabled` | `false` | Create a folder with contents of the secret in the pod's container |
| `mountSecret.path` | `/var/lib/secret` | Where to mount secret data |
| `mountSecret.data` | `{}` | Key-value list of files to be mount into the container |
| `persistence.enabled` | `true` | Persist Postfix's queue on disk |
| `persistence.accessModes` | `[ 'ReadWriteOnce' ]` | Access mode |
| `persistence.existingClaim` | `""` | Provide an existing `PersistentVolumeClaim`, the value is evaluated as a template. |
| `persistence.size` | `1Gi` | Storage size |
| `persistence.storageClass` | `""` | Storage class |
| `recreateOnRedeploy` | `true` | Restart Pods on every helm deployment, to prevent issues with stale configuration(s). |

### Metrics

You may enable metrics on the cart by simply setting `metrics.enabled=true`. Of course, this comes with some caveats, namely:

- Postfix logs will (by default, if you don't override this) go to `/var/log/mail.log` _as well_ as to stdout.
- `/var/log/mail.log` will be in plain-text format (always), no matter what you set `LOG_FORMAT` to

Please see helm chart's `values.yaml` for further configuration options and how to enable `ServiceMonitor`, if you need it for
Prometheus.

## Extending the image

### Using custom init scripts

If you need to add custom configuration to postfix or have it do something outside of the scope of this configuration,
simply add your scripts to `/docker-init.db/`: All files with the `.sh` extension will be executed automatically at the
end of the startup script.

E.g.: create a custom `Dockerfile` like this:

```shell script
FROM boky/postfix
LABEL maintainer="Jack Sparrow <jack.sparrow@theblackpearl.example.com>"
ADD Dockerfiles/additional-config.sh /docker-init.db/
```

Build it with docker, and your script will be automatically executed before Postfix starts.

Or -- alternately -- bind this folder in your docker config and put your scripts there. Useful if you need to add a
config to your postfix server or override configs created by the script.

For example, your script could contain something like this:

```shell script
#!/bin/sh
postconf -e "address_verify_negative_cache=yes"
```

## Security

Postfix will run the master proces as `root`, because that's how it's designed. Subprocesses will run under the `postfix`
and `opendkim` accounts.

### UIDs/GIDs numbers

While I cannot guarantee IDs (they are auto-generated by package manages), they tend to be fairly consistent across 
**specific distribution**. Please be aware of this if you are switching images from Alpine to Debian to Ubuntu or
back.

At the last check, images had the following UIDs/GIDs:

| Service    | Debian (`UID/GID`) | Ubuntu (`UID/GID`) | Alpine (`UID/GID`) |
|------------|--------------------|--------------------|--------------------|
| `postfix`  | `100:102`          | `101:102`          | `100:101`          |
| `opendkim` | `101:104`          | `102:104`          | `102:103`          |

Please check the notification information on startup.

## Quick how-tos

### Relaying messages through your Gmail account

Please note that Gmail does not support using your password with non-OAuth2 clients. You will need to either enable
[Less secure apps](https://support.google.com/accounts/answer/6010255?hl=en) in your account and assign an "app password",
or [configure postfix support for XOAuth2 authentication](#xoauth2_client_id-xoauth2_secret-xoauth2_initial_access_token-and-xoauth2_initial_refresh_token).
You'll also need to use (only) your email as the sender address.

If you follow the *less than secure* route, your configuration would be as follows:

```shell script
RELAYHOST=smtp.gmail.com:587
RELAYHOST_USERNAME=you@gmail.com
RELAYHOST_PASSWORD=your-gmail-app-password
ALLOWED_SENDER_DOMAINS=gmail.com
```

There's no need to configure DKIM or SPF, as Gmail will add these headers automatically.

### Relaying messages through Google Apps account

Google Apps allows third-party services to use Google's SMTP servers without much hassle. If you have a static IP, you
can configure Gmail to accept your messages. You can then send email *from any address within your domain*.

You need to enable the [SMTP relay service](https://support.google.com/a/answer/2956491?hl=en):

* Go to Google [Admin /Apps / G Suite / Gmail /Advanced settings](https://admin.google.com/AdminHome?hl=en_GB#ServiceSettings/service=email&subtab=filters).
* Find the **Routing / SMTP relay service**
* Click **Add another** button that pops up when you hover over the line
* Enter the name and your server's external IP as shown in the picture below:
  * **Allowed senders:** Only registered Apps users in my domains
  * Select **Only accept mail from specified IP Addresses**
  * Click **Add IP RANGE** and add your external IP
  * Make sure **Require SMTP Authentication** is **NOT** selected
  * You *may* select **Require TLS encryption**

![Add setting SMTP relay service](GApps-SMTP-config.png)

Your configuration would be as follows:

```shell script
RELAYHOST=smtp-relay.gmail.com:587
ALLOWED_SENDER_DOMAINS=<your-domain>
```

There's no need to configure DKIM or SPF, as Gmail will add these headers automatically.

### Relaying messages through Amazon's SES

If your application runs in Amazon Elastic Compute Cloud (Amazon EC2), you can use Amazon SES to send up to 62,000 emails
every month at no additional charge. You'll need an AWS account and SMTP credentials. The SMTP settings are available
on the SES page. 

For example, for `eu-central-1`:

- Please See the [SES Page for Details](https://eu-central-1.console.aws.amazon.com/ses/home?region=eu-central-1#smtp)

You need Amazon SES SMTP credentials to access the SES SMTP interface.
**NOTE:** Your SMTP password is different from your AWS secret access key.  Additionally, the credentials that you use to send email through the SES SMTP interface are unique to each _AWS Region_. If you use the SES SMTP interface to send email in more than one Region, you must generate a set of SMTP credentials for each Region that you plan to use.

- [Create or Obtain the User Credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html)

**Make sure you write the user credentials down, as you will only see them once.**

By default, messages that you send through Amazon SES use a subdomain of `amazonses.com` as the `MAIL FROM` domain. See
[Amazon's documentation](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/mail-from.html) on how the domain can
be configured.

Your configuration would be as follows (example data, these key *will not work*):

```shell script
RELAYHOST=email-smtp.eu-central-1.amazonaws.com:587
RELAYHOST_USERNAME=AKIAGHEVSQTOOSQBCSWQ
RELAYHOST_PASSWORD=BK+kjsdfliWELIhEFnlkjf/jwlfkEFN/kDj89Ufj/AAc
ALLOWED_SENDER_DOMAINS=<your-domain>
```

You will need to configure DKIM and SPF for your domain as well.

### Sending messages directly

If you're sending messages directly, you'll need to:

- have a fixed IP address;
- configure a reverse PTR record;
- configure SPF and/or DKIM as explained in this document;
- it's also highly advisable to have your own IP block.

Your configuration would be as follows:

```shell script
ALLOWED_SENDER_DOMAINS=<your-domain>
```

#### Careful

Getting all of this to work properly is not a small feat:

- Hosting providers will regularly block outgoing connections to port 25. On AWS, for example you can
  [fill out a form](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/) and request for
  port 25 to be unblocked.
- You'll most likely need to at least [set up SPF records](https://en.wikipedia.org/wiki/Sender_Policy_Framework) or
  [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail).
- You'll need to set up [PTR](https://en.wikipedia.org/wiki/Reverse_DNS_lookup) records to prevent your emails going
  to spam.
- Microsoft is especially notorious for trashing emails from new IPs directly into spam. If you're having trouble
  delivering emails to `outlook.com` domains, you will need to enroll in their
  [Smart Network Data Service](https://sendersupport.olc.protection.outlook.com/snds/) programme. And to do this you
  will need to *be the owner of the netblock you're sending the emails from*.

## Similar projects

There are may other project offering similar functionality. The aim of this project, however, is:

* to make it as simple as possible to run the relay, without going too much into postfix configuration details
* to make the image as small as possible (hence basing on Alpine linux)
* to make the image and the corresponding code testable

The other projects are, in completely random order:

- [wader/postfix-relay](https://github.com/wader/postfix-relay)
- [catatnight/postfix](https://github.com/catatnight/docker-postfix)
- [juanluisbaptiste/docker-postfix](https://github.com/juanluisbaptiste/docker-postfix)
- [docker-mail-relay](https://github.com/alterrebe/docker-mail-relay)
- [applariat/kubernetes-postfix-relay-host](https://github.com/applariat/kubernetes-postfix-relay-host)
- [eldada/postfix-relay-kubernetes](https://github.com/eldada/postfix-relay-kubernetes)

## License check

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fbokysan%2Fdocker-postfix.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fbokysan%2Fdocker-postfix?ref=badge_large)
