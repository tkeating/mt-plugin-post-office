## PostOffice, a plugin for Movable Type
## Author: Six Apart, http://www.sixapart.com/
##
## Modified and improved by Tom Keating, http://blog.tmcnet.com/blog/tom-keating/
## Version: 2.0
## Released under GPL2
##

## OVERVIEW ##
## You can specify what category posts will end up in by titling your e-mails in the format "[Category] Title Goes Here" (no quotes) 
## http://wiki.movabletype.org/Documentation:PostOffice
## Tom Keating's Forked Features in v2.0
## iPhone video upload / auto-embed 
## Max image setting per blog + auto-resize to fit max size
This plugin enables users to post to their blog via email.

## PREREQUISITES ##

* Mail::IMAPClient (for IMAP)
* Mail::POP3Client (for POP)
* Email::Address
* Email::MIME
* use Image::Magick
* use Image::ExifTool
* use Image::Size
* IO::Socket::SSL

## FEATURES ##

Post Office is a plugin for Movable Type that allows users to post to 
their blog via email. It works by connecting Movable Type to an 
existing email account, like GMail or any POP or IMAP compliant mailbox, 
and periodically scanning for messages to post. Each user can be given 
a unique email address to which to post to uniquely identify them and 
the blog they want to post to when sending an email. 

    Images are now imported into MT Asset Management database, so they can be used in a slideshow, search results, etc. {Note: PostOffice v1.1 added this feature too}
    Videos are also now imported into MT Asset Management database.
    Both images and videos are now stored in /images/YYYY/MM dated folders instead of a single directory like PostOffice 1.0 & 1.1.
    Ability for each blogger to set a maximum image width so they don't 'blow' out their blog layout with an image that is too wide.
    Images are resized automatically if larger than maximum width
    Detect html or text email format and set the line breaks for the entry automatically. {Credit: Alex Teslik www.acatysmoof.com}
    Process message parts in a single loop (instead of two loops as in 1.1) while still replacing cid and loc links with the correct asset. The structure allows for future modifications, such as the automatic embedding of videos, audio files, etc. {Credit: Alex Teslik www.acatysmoof.com}
    Auto-rotate email images based on EXIF tags. Originally I was running this cron job to auto-rotate all images based on EXIF data:
    /usr/bin/jhead -autorot -ft /var/www/html/blog/tom-keating/images/*
    Now I can rotate images with PostOffice using Image::ExifTool. This allows iPhone and iPad users to mail images to their blog and have them appear correctly. The EXIF tag is updated after rotation so that Mobile Safari and some other browsers do not rotate the image again based on the EXIF orientation tag.
    Disabled plus style email addressing used by PostOffice 1.0 and 1.1, which expects email addresses using the format emailaddress+{blogid}@domain.com, i.e. tomkeating+5@tmcnet.com. However, since most email servers DO NOT support plus-style addressing, this was preventing me from getting this plugin to work with Exchange Server 2010. I commented out the code, so you can re-enable it if you wish, though I suspect most will prefer it disabled.
Future features:

    Support for spaces tags in Subject line, i.e.: #ip communications, #windows 8 [will likely require comma as tag separator]
    Support for default category if unassigned
    If using IMAP I may specify a specific folder to monitor, i.e. BlogEmails. This way, you don't have to setup a separate 'dummy' email account to use. You can use your regular email account. Then you just setup an email (Outlook) rule that moves an inbound email with certain email-to-blog characteristics to this BlogEmails folder.

## INSTALLATION ##

  1. Copy the contents of PostOffice/plugins into /path/to/mt/plugins/
  2. Navigate to the settings area for PostOffice and enter in the
     connection info for your email provider.
  3. Ensure that you have an API Password selected for yourself. Edit
     your profile if you need to select one.
  4. Click the Write Entry button and scroll to the bottom of the screen.
     Look for the text "Email to <blog name>".
  5. Save the email address linked to in your address book. Send a test
     email.

## SUPPORT ##

For support, please visit our forums:

   http://forums.movabletype.org/

## SOURCE CODE ##

Source

Github (latest):
https://github.com/endevver/mt-plugin-post-office

OLD info:

SVN Repo:
    http://code.sixapart.com/svn/mtplugins/trunk/PostOffice

Trac View:
    http://code.sixapart.com/trac/mtplugins/log/trunk/PostOffice

Plugins:
    http://plugins.movabletype.org/post-office/


## LICENSE ##

GPL 2.0

## AUTHOR ##

Copyright 2008, Six Apart, Ltd. All rights reserved.