## Post Office 2.0, a plugin for Movable Type

* Author: Six Apart
* Released under GPL2

## OVERVIEW ##

Post Office is a plugin for Movable Type that allows users to post to their
blog via email. It works by connecting Movable Type to an existing email
account, like GMail or any POP or IMAP compliant mailbox, and periodically
scanning for messages to post.

Depending upon your configuration preferences, each user can be given a unique
email address to post an entry to, uniquely identifying them and the blog they
want to post to when sending an email.

You can specify the Category & multiple tags using email Subject line
Subject format = [Category] Title Goes Here #tag1 #tag2 #tag2

### Forked Features in v2.0
* iPhone video upload / auto-embed 
* Max image setting per blog + auto-resize to fit max size
* Auto-rotate email images based on EXIF tags. 
* Disabled plus style email addressing used by PostOffice 1.0 and 1.1, which
  expects email addresses using the format emailaddress+{blogid}@domain.com, 
  i.e. tomkeating+5@tmcnet.com. However, since most email servers DO NOT 
  support plus-style addressing, this was preventing me from getting this
  plugin to work with Exchange Server 2010. I commented out the code, so you
  can re-enable it if you wish, though I suspect most will prefer it disabled.

## INSTALLATION ##

### Prerequisites ###

* Mail::IMAPClient (for IMAP)
* Mail::POP3Client (for POP)
* Email::Address
* Email::MIME
* use Image::Magick
* use Image::ExifTool
* use Image::Size
* IO::Socket::SSL

### Download ###

The latest version of the plugin can be downloaded from the its
[Github repo][]. [Packaged downloads][] are also available if you prefer.

[Github repo]:
    https://github.com/tkeating/mt-plugin-post-office
[Packaged downloads]:
    https://github.com/tkeating/mt-plugin-post-office/downloads

Copy the contents of PostOffice/plugins into /path/to/mt/plugins/

`run-periodic-tasks` must be configured. Further details can be found on the
page [Setting up run-periodic-tasks][].

[Setting up run-periodic-tasks]:
    http://www.movabletype.org/documentation/administrator/setting-up-run-periodic-taskspl.html


## FEATURES ##

* Images are now imported into MT Asset Management database, so they can be used in a slideshow, search results, etc. {Note: PostOffice v1.1 added this feature too}
* Videos are also now imported into MT Asset Management database.
* Both images and videos are now stored in /images/YYYY/MM dated folders instead of a single directory like PostOffice 1.0 & 1.1.
* Ability for each blogger to set a maximum image width so they don't 'blow' out their blog layout with an image that is too wide.
* Images are resized automatically if larger than maximum width
* Detect html or text email format and set the line breaks for the entry automatically. {Credit: Alex Teslik www.acatysmoof.com}
* Process message parts in a single loop (instead of two loops as in 1.1) while still replacing cid and loc links with the correct asset. The structure allows for future modifications, such as the automatic embedding of videos, audio files, etc. {Credit: Alex Teslik www.acatysmoof.com}
* Auto-rotate email images based on EXIF tags. Originally I was running this cron job to auto-rotate all images based on EXIF data:
* /usr/bin/jhead -autorot -ft /var/www/html/blog/tom-keating/images/*
* Now I can rotate images with PostOffice using Image::ExifTool. This allows iPhone and iPad users to mail images to their blog and have them appear correctly. The EXIF tag is updated after rotation so that Mobile Safari and some other browsers do not rotate the image again based on the EXIF orientation tag.
* Disabled plus style email addressing used by PostOffice 1.0 and 1.1, which expects email addresses using the format emailaddress+{blogid}@domain.com, i.e. tomkeating+5@tmcnet.com. However, since most email servers DO NOT support plus-style addressing, this was preventing me from getting this plugin to work with Exchange Server 2010. I commented out the code, so you can re-enable it if you wish, though I suspect most will prefer it disabled.

## Future features ##

* Support for spaces tags in Subject line, i.e.: #ip communications, #windows 8 [will likely require comma as tag separator]
* Support for default category if unassigned - OR can just use this plugin (tested & works): [Default Category](https://github.com/danwolfgang/mt-plugin-default-category)
* If using IMAP I may specify a specific folder to monitor, i.e. BlogEmails. This way, you don't have to setup a separate 'dummy' email account to use. You can use your regular email account. Then you just setup an email (Outlook) rule that moves an inbound email with certain email-to-blog characteristics to this BlogEmails folder.
## CONFIGURATION ##

Navigate to Tools > Plugins > Post Office > Settings and enter in the
connection info for your email provider as well as author and entry
preferences. Note that this plugin can be configured at the system or blog
level.

### Email Destination Configuration

The following fields configure Post Office's connection to the address that
users send new entries to.

* Destination Inbox: The email address authors send posts to when they want
  Movable Type to post those messages to this blog.

* Mail Server Type: POP3 or IMAP

* Email Account Host: The host for the email account which Movable Type uses
  to post to this blog. Example: `pop.gmail.com`.

* Use SSL: check if the host requires an encrypted connection. (If using Gmail
  or Google Apps, check Use SSL.)

* Email Account Username: The username for the email account which Movable
  Type uses to post to this blog. (If using Gmail or Google Apps, specify the
  email address as in the Destination Inbox field.)

* Email Account Password: The password for the email account which Movable
  Type uses to post to this blog.

### Entry and Author Configuration

* Default Post Status: This determines if entries are automatically published
  as they are received ("Published") or if they must be manually published
  ("Draft").

* Embed Attachments: By default, a photo attached to an email will become an
  asset, an asset-entry relationship will be created, and the asset will be
  embedded at the end of the entry. Uncheck this option to *not* embed the
  asset (but still turn attachments into assets and create the asset-entry
  relationship).

* Allow all MT Authors from this Blog to Post: If you check this box, Movable
  Type will allow all of the authors of this weblog to post via email using
  the email address in their author profile.

* Require Web Services Password in Address: If you check this box, Post Office
  will require users to include their Web Service Password as an extension on
  their e-mail address. So the "From" address should contain a "+" followed by
  their Web Services Password value. This provides additional authentication
  for incoming messages. (i.e., user+nnnnn@...)

* Email Addresses Allowed to Post: Movable Type will post messages received
  from these email addresses. Separate multiple addresses with a comma.

* Allow Any Email: This option will simply publish any email received in the
  destination inbox. Users are not authenticated in any way, making posting
  completely anonymous. The Default Author is assigned entry ownership in this
  case.

* Email Alias Matches MT Username: Checking this box will result in Post
  Office looking for a matching MT user based on the alias portion of the
  sender email address (the part before the @ sign). For example, if the email
  was sent by `johnsmith@domain.com`, Post Office would check to see if there
  is an MT Author with the username `johnsmith`. If a match is found, the
  entry will be posted as that MT user (if the user has posting permissions in
  the blog). If no match is found, Post Office will still try to look for a
  user with a matching email address.

* Default Author: This is the "default" author, the person to whom entries are
  assigned if no other valid author exists. Email addresses specified in the
  above field will be attributed to this author if they are not valid Authors.


## USE ##

Before you can start emailing entries to your configured blog, you need to
grab a specially-crafted email address: click the Write Entry button in the
configured blog and scroll to the bottom of the screen. Look for the text
"Email to <blog name>". Click this link and/or save the provided email address
to your address book.

If you've selected the "Require Web Services Password in Address"
configuration option you may notice that your web services password is part of
the address in the "Email to <blog name>" link. If this feature is enabled
note that the "Email to <blog name>" address is unique to each user.

Finally, now that you've got this email address you can send an email to test
posting!

### Drafting an Email Entry

Post Office will look at your email contents to create an entry formatted just
as you require.

The subject of your email becomes the Entry Title. The body of your email
becomes the Entry Body. If any files are attached to your email, they will be
converted into Assets.

The subject of your email can also specify a category and tags for your entry.
A basic subject line that becomes the Entry Title might look like this:

    My first emailed entry!

Specifying a category in addition to the Entry Title is easy: include brackets
around the category name. If the specified category doesn't exist, it will be
created for you when the message is processed. Only one category may be
specified.

    [Movable Type Tests] My first emailed entry!

Additionally, specifying a category, Entry Title, and tags is easy. Specify
tags with a leading hashmark; many tags can be specified.

    [Movable Type Tests] My first emailed entry! #PostOffice #Email

Lastly, send your email!

## LICENSE ##

GPL 2.0

## AUTHOR ##

Copyright 2008-2010, Six Apart Ltd., All rights reserved.
