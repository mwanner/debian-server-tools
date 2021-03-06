# Mail servers

### E-mail server factors

- Transport encryption (TLS on SMTP in&out and IMAP)
- Forwarding with SRS (Sender Rewriting Scheme)
- [Fetch instead of forwarding](http://scribu.net/blog/properly-forwarding-email-to-gmail.html)
- Attack mitigation (SMTP vulnerability, authentication)
- Spam filtering
- Custom blackhole lists (RBL)
- Custom whitelisting of hosts (broken mail servers)
- Monitor IP reputation
- Apply to whitelists
- Register to feedback loops
- Monitor delivery and delivery errors

### Transactional email providers

- https://www.mailjet.com/transactional Made with :heart: in Paris
- https://www.mailgun.com/ by Rackspace
- https://aws.amazon.com/ses/ by Amazon
- https://sendgrid.com/
- https://www.sendinblue.com/
- https://www.mandrill.com/ by MailChimp
- https://postmarkapp.com/ by Wildbit

### Marketing tools

- https://www.getdrip.com/features
- https://www.campaignmonitor.com/

### Webmails

http://www.rainloop.net/changelog/

### Disposable email address

http://nincsmail.hu/ (inbox and sending)


## Problems


### Outlook 2013 fixes

- Root: "Inbox"
- To recognize standard folder names [delete .pst/.ost file](http://answers.microsoft.com/en-us/office/forum/office_2013_release-outlook/outlook-2013-with-imap-deleted-items-and-trash-i/9ec6e501-8e1a-45cf-bb90-cb9e2205d025)
after account setup
- Fix folder subscription, see: ${D}/mail/courier-outlook-subscribe-bug.sh (Outlook 2007)

### MacOS Mail.app fixes

Advanced/IMAP Path Prefix: "INBOX"

### Open winmail.dat

https://github.com/Yeraze/ytnef

See: ${D}/repo/debian/pool/main/y/ytnef/

MIME type: application/ms-tnef

### Set up Google Apps mailing

https://toolbox.googleapps.com/apps/checkmx/

### Online IMAP migration

- see: mail/imapsync
- [OVH ImapCopy](https://ssl0.ovh.net/ie/imapcopy/)
- [OfflineIMAP](https://github.com/OfflineIMAP/offlineimap)

### Email filters

- https://www.mailscanner.info/install/
- https://wiki.efa-project.org/

### Decode emails

- Encoded (base64 or QP) headers: `conv2047.pl -d`
- Body and attachments: `munpack -t`
- Syntax highlight: `headers.vim` for vim, `/input/mc/email.syntax` for mcedit
- Enveloped-data (application/pkcs7-mime): `cat smime.p7m | base64 -d | openssl smime -verify -inform DER`


## Settings


### Malware (virus) scanning

- ClamAV (CCTTS, Safe Browsing)
- clamav-unofficial-sigs (paid: SecuriteInfo, MalwarePatrol, free: Sanesecurity)
- `clamav.py` pythonfilter through pyClamd for Courier MTA

clamav-unofficial-sigs needs 1 GB of memory.

See "Best clamd.conf" in [SecuriteInfo](https://www.securiteinfo.com/services/anti-spam-anti-virus/improve-detection-rate-of-zero-day-malwares-for-clamav.shtml) FAQ.

### Block executables

courier-pythonfilter module: `attachments.py`

```ini
[attachments.py]
blockedPattern = r'^.*\.(ade|adp|bat|chm|cmd|com|cpl|dll|exe|hta|inf|ins|isp|jar|js|jse|lib|lnk|mde|msc|msp|mst|pif|reg|scf|scr|sct|shb|shs|sys|url|xxe|vb|vbe|vbs|vxd|wsc|wsf|wsh)$'
```

### GMail's blocked file types

https://support.google.com/mail/answer/6590

[Spamassassin rule](https://spamassassin.apache.org/full/3.4.x/doc/Mail_SpamAssassin_Plugin_MIMEHeader.html)

`20_gmail-blocked-filetypes.cf`

```
# GMail's blocked file types
ifplugin Mail::SpamAssassin::Plugin::MIMEHeader
mimeheader GMAIL_BLOCKED_ATTACH Content-Type =~ /\.(ADE|ADP|BAT|CHM|CMD|COM|CPL|EXE|HTA|INS|ISP|JAR|JSE|LIB|LNK|MDE|MSC|MSP|MST|PIF|SCR|SCT|SHB|SYS|VB|VBE|VBS|VXD|WSC|WSF|WSH)/i
mimeheader GMAIL_BLOCKED_ATTACH_CD Content-Disposition =~ /\.(ADE|ADP|BAT|CHM|CMD|COM|CPL|EXE|HTA|INS|ISP|JAR|JSE|LIB|LNK|MDE|MSC|MSP|MST|PIF|SCR|SCT|SHB|SYS|VB|VBE|VBS|VXD|WSC|WSF|WSH)/i
score GMAIL_BLOCKED_ATTACH 20
score GMAIL_BLOCKED_ATTACH_CD 20
endif
```

### Send all messages in an mbox file to an email address

See: [mbox_send2.py](./mbox_send2.py)

### Email forwarding (srs)

Build Courier SRS

See: `/package/couriersrs-jessie.sh`

### Courier catchall address

http://www.courier-mta.org/makehosteddomains.html

http://www.courier-mta.org/dot-courier.html

Add alias: `@target.tld:  foo`

Delivery instructions:

```bash
echo "|/pipe/command" > /var/mail/localhost/user/.courier-foo-default
```

### Spamtrap

```
spamtrap@domain.net:  |/usr/local/bin/multi-stdout.sh "/usr/bin/spamc -4 --learntype=spam --max-size=1048576" "/usr/bin/spamc -4 --reporttype=report --max-size=1048576"
problematic@address.es:  spamtrap@domain.net
```

### NAIH nyilvántartási szám - "Hungarian National Authority for Data Protection and Freedom of Information" registry

[NAIH kereső](http://81.183.229.204:8080/EMS/EMSDataProtectionRequest/Finder)
http://www.naih.hu/kereses-az-adatvedelmi-nyilvantartasban.html

### Courier kitchen sink (drop incoming messages)

See the description of `/etc/courier/aliasdir` in `man dot-courier` DELIVERY INSTRUCTIONS

`echo "" > /etc/courier/aliasdir/.courier-kitchensink`

Add alias: `ANY.ADDRESS@ANY.DOMAIN.TLD:  kitchensink@localhost`


### Courier MTA message processing order on reception

1. SMTP communication
1. NOADD*, `opt MIME=none`
1. filters
1. DEFAULTDELIVERY

### Courier MTA log analyzer

[Courier-analog](http://www.courier-mta.org/download.html#analog)

### Courier as smarthost client

`esmtproutes` "both MX and A records get looked up"


## Test


### IMAP PLAIN authentication

```imap
D0 CAPABILITY
D1 AUTHENTICATE PLAIN
$(echo -en "\0USERNAME\0PASSWORD" | base64)
D2 LOGOUT
```

### Spamassassin test and email authentication

```bash
sudo -u daemon -- spamassassin --test-mode --prefspath=/var/mail/.spamassassin/user_prefs -D < msg.eml

# For specific tests see: man spamassassin-run
sudo -u daemon -- spamassassin --test-mode --prefspath=/var/mail/.spamassassin/user_prefs -D dkim < msg-signed.eml

opendkim -vvv -t msg-signed.eml
```

### Mailserver SSL test

https://ssl-tools.net/

### Authentication

- https://www.unlocktheinbox.com/resources/identifieralignments/
- http://www.openspf.org/Related_Solutions

#### SPF (HELO, MAIL FROM:)

- setup http://www.spfwizard.net/
- check http://www.kitterman.com/spf/validate.html http://tools.wordtothewise.com/authentication
- monitor `host -t TXT <domain>; pyspf`
- For non-email domains: `v=spf1 -all`

#### Sender ID from Microsoft (From:)

- http://en.wikipedia.org/wiki/Sender_ID
- http://tools.ietf.org/html/rfc4407#section-2
- PRA: Resent-Sender > Resent-From > Sender > From > ill-formed
- http://www.appmaildev.com/

#### DKIM

- [RFC 6376](https://tools.ietf.org/html/rfc6376)
- setup http://www.tana.it/sw/zdkimfilter/
- check
- monitor

##### DKIM tests

- check-auth@verifier.port25.com
- autorespond+dkim@dk.elandsys.com
- test@dkimtest.jason.long.name
- dktest@exhalus.net
- dkim-test@altn.com
- dktest@blackops.org
- http://www.brandonchecketts.com/emailtest.php
- http://www.appmaildev.com/en/dkim/
- http://9vx.org/~dho/dkim_validate.php
- https://protodave.com/tools/dkim-key-checker/ (DNS only)

#### Domain Keys

Deprecated.

#### ADSP

An optional extension to the DKIM E-mail authentication scheme.

https://unlocktheinbox.com/resources/adsp/

#### DMARC

Specs: https://datatracker.ietf.org/doc/draft-kucherawy-dmarc-base/?include_text=1

- setup https://unlocktheinbox.com/dmarcwizard/
- check
- monitor `host -t TXT _dmarc.$DOMAIN`

http://www.returnpath.com/solution-content/dmarc-support/what-is-dmarc/

### Bulk mail

#### Body parts

- :sunny: :sunny: :sunny: Descriptive From name "Firstname from Company"
- :sunny: :sunny: Descriptive subject line
- :sunny: Short preview line at top of the message
- Link to online version (newsletter archive)
- Short main header
- :bulb: Sections: image + title + description + call2action, see: https://litmus.com/subscribe
- External resources should be able to load through HTTPS (opening in a HTTPS webmail)
- :iphone: Mobile compatible

#### Footer

- Sender's contact details (postal address, phone number)
- Who (recipient name, email address, why) is subscribed
- Unsubscribe link
- Forward to a friend

#### Email headers

- `List-Unsubscribe: URL` (invisible)
- `Precedence: bulk` (invisible)
- `Return-Path: bounce@addre.ss` (invisible)
- `Reply-to: reply@addre.ss` (invisible) [How to video](https://youtu.be/mGSPj4CyOMQ?t=1m20s)
- `From: sender@domain.net`
- `To: recipients@addre.ss`
- bounce `X-Autoreply: yes`
- bounce `Auto-Submitted: auto-replied`

#### Others

- SMTP `MAIL FORM: <user@domain.net>`
- HTML and plain text payload
- From address SPF `include:servers.mcsv.net`
- [Bulk Senders Guidelines by Google](https://support.google.com/mail/answer/81126)
- [Spamhaus Marketing FAQ](https://www.spamhaus.org/faq/section/Marketing%20FAQs)
- :cloud: CDN for images

### Email templates

- https://litmus.com/community/templates
- https://litmus.com/blog/go-responsive-with-these-7-free-email-templates-from-stamplia
- https://www.klaviyo.com/
- https://litmus.com/subscribe
- https://stamplia.com/

### Email tests

- https://www.mail-tester.com/ by Mailpoet
- http://spamcheck.postmarkapp.com/
- mailtest@unlocktheinbox.com https://www.unlocktheinbox.com/resources/emailauthentication/
- checkmyauth@auth.returnpath.net
- https://winning.email/checkup/DOMAIN

#### HTML content

- https://inlinestyler.torchbox.com/styler/
- https://putsmail.com/

### RBL-s (DNSBL)

#### Blacklists

- `BLACKLISTS="-block=bl.blocklist.de"`
- http://psky.me/
- http://www.intra2net.com/en/support/antispam/index.php (Blacklist Monitor)
- http://multirbl.valli.org/
- https://mxtoolbox.com/problem/blacklist/ [chart](https://mxtoolbox.com/Public/ChartHandler.aspx?type=TopBlacklistActivity)
- http://bgp.he.net/ip/1.2.3.4#_rbl
- http://www.unifiedemail.net/Tools/RBLCheck/

#### Check RBL-s

```bash
rblcheck
```

Trendmicro ERS check

```bash
wget -qO- --post-data="_method=POST&data[Reputation][ip]=${IP}" https://ers.trendmicro.com/reputations \
    | sed -ne 's;.*<dd>\(.\+\)</dd>.*;\1;p' | tr '\n' ' '
```

OK response: "IP Unlisted in the spam sender list None"

### IP reputation

- http://www.senderbase.org/lookup/
- https://www.senderscore.org/lookup.php
- http://www.barracudacentral.org/lookups
- http://www.cyren.com/ip-reputation-check.html
- http://www.mcafee.com/threat-intelligence/ip/spam-senders.aspx
- http://www.mcafee.com/threat-intelligence/ip/default.aspx?ip=1.2.3.4
- http://ipremoval.sms.symantec.com/lookup/
- https://postmaster.aol.com/ip-reputation
- https://ers.trendmicro.com/reputations
- http://www.projecthoneypot.org/search_ip.php

#### IP reputation monitoring

- https://mxtoolbox.com/services_servermonitoring2.aspx
- https://www.projecthoneypot.org/monitor_settings.php
- https://www.rblmon.com/accounts/register/
- https://rbltracker.com/

### Whitelists

- https://www.dnswl.org/selfservice/
- http://www.emailreg.org/index.cgi?p=policy (Barracuda)
- https://ers.trendmicro.com/reputations/global_approved_list
- [Whitelists in SpamAssassin](https://wiki.apache.org/spamassassin/DnsBlocklists#Whitelists)

### Feedback loops, postmaster tools, sender support

- https://wordtothewise.com/isp-information/
- [Smart Network Data Service (SNDS)](http://postmaster.live.com/snds/) + JMRP
- [Sender Information for Outlook.com Delivery](http://go.microsoft.com/fwlink/?LinkID=614866)
- https://www.dnswl.org/selfservice/
- https://support.google.com/mail/contact/msgdelivery
- https://postoffice.yandex.com/
- http://yandexfbl.senderscore.net/
- http://poczta.onet.pl/pomoc/en,odblokuj.html
- [Report abuse from Gmail](https://support.google.com/mail/contact/abuse)
- [Report abuse from Outlook.com](mailto:abuse@outlook.com)
- [Abuse Contact DB](https://abusix.com/contactdb.html) `host -t TXT $(revip IP-ADDRESS).abuse-contacts.abusix.org`

### Free e-mail backup server

http://www.junkemailfilter.com/spam/free_mx_backup_service.html
