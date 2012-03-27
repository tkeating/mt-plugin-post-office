package PostOffice;

use strict;
use warnings;
use MT::Util qw(html_text_transform perl_sha1_digest_hex);

use File::Spec;
use File::Basename;
use Email::Address;
use Email::MIME;
use Email::MIME::ContentType;
use Image::Magick;
use Image::ExifTool;
use Image::Size; #TK Added

our $DEBUG = 0;
our @files; #TK Added
our $cfgglobal; #TK - global var holding cfg plugin settings for blog being pushlished

sub plugin {
    return MT->component('postoffice');
}

sub deliver {
    my $pkg = shift;

    my $plugin = $pkg->plugin;

    require MT::PluginData;
    my $pd_iter = MT::PluginData->load_iter( { plugin => $plugin->key } );
    return unless $pd_iter;

#  loops through all blogs with PostOffice configured
    my $count = 0;
    while ( my $pd = $pd_iter->() ) {
        next unless $pd->key =~ m/^configuration:blog:(\d+)/;
        my $blog_id = $1;
        print "Checking inbox for blog $blog_id...\n"
          if $DEBUG;
        my $cfg = $pd->data() || {};
        next unless $cfg->{email_username};

        my $blog_count = $pkg->process_messages( $blog_id, $cfg );
        if ( defined $blog_count ) {
            print "Delivered $blog_count messages for blog $blog_id...\n"
              if $DEBUG;
            $count += $blog_count;
        }
    }

    my $sys_cfg = $plugin->get_config_hash() || {};
    if ( $sys_cfg->{email_username} ) {
        print "Checking inbox for system-configured inbox...\n";
        my $sys_count = $pkg->process_messages( undef, $sys_cfg );
        if ( defined $sys_count ) {
            print "Delivered $sys_count messages...\n"
              if $DEBUG;
            $count += $sys_count;
        }
    }

    $count;
}

sub save_attachment {
    my $pkg = shift;
    my ( $blog, $file ) = @_;

    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file( $file->{path} );

    my $asset;
    $asset = $asset_pkg->new();
    $asset->file_path( $file->{path} );
    $asset->file_name( $file->{name} );
    $file->{name} =~ /(.*)(?:\.)(.*$)/;
    $asset->file_ext($2);
    $asset->url( $file->{url} );
    $asset->mime_type( $file->{media_type} );
    $asset->blog_id( $blog->id );
    $asset->save || return undef;

    MT->run_callbacks(
        'api_upload_file.' . $asset->class,
        File  => $file->{path},
        file  => $file->{path},
        Url   => $file->{url},
        url   => $file->{url},
        Size  => $file->{size},
        size  => $file->{size},
        Asset => $asset,
        asset => $asset,
        Type  => $asset->class,
        type  => $asset->class,
        $blog ? ( Blog => $blog ) : (),
        $blog ? ( blog => $blog ) : ()
    );

    return $asset;
}

sub _parse_content_type {
    my ($content_type) = @_;

    my $data = Email::MIME::ContentType::parse_content_type($content_type);
    my $media_type = $data->{discrete} . "/" . $data->{composite};
    my $charset    = $data->{attributes}->{charset};
    return ( $media_type, $charset );
}

sub _unique_filename {
    my ( $fmgr, $site_path, $filename ) = @_;

    my ( $basename, undef, $suffix ) =
      File::Basename::fileparse( $filename, qr/\.[^.]*/ );

    my $u = '';
    my $i = 1;
    while (
        $fmgr->exists(
            File::Spec->catfile( $site_path, $basename . $u . $suffix )
        )
      )
    {
        $u = '_' . $i++;
    }
    $basename . $u . $suffix;
}

sub process_file_part {
   # given a message part that is a file attachment, save it as an MT Asset
   # and return the post text to link to that asset
   my ($pkg, $blog, $msg, $charset, $media_type, $part) = @_;
#TK added next 5 lines
    my $blog_idtom = @_;
    my $app = MT->app;
    if ($app->isa('MT::App')) {
        $blog_idtom ||= $app->param('blog_id');
    }
   # store the asset in a dated folder like 2010/10/17/
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   my $yyyymmdd = sprintf "%04d/%02d/%02d/", $year+1900, $mon+1, $mday;

   #TK Orig my $filepath = $blog->site_path . '/' . $yyyymmdd;
   my $filepath = $blog->site_path . '/images/' . $yyyymmdd;
   my $urlpath  = $blog->site_url . 'images/' . $yyyymmdd;

   my $fmgr = $blog->file_mgr;
   $fmgr->mkpath($filepath);

   require MT::I18N;
   my $filename = MT::I18N::encode_text( $part->filename, $charset );
   $filename    = _unique_filename( $fmgr, $filepath, $filename );

   my $fullpath = File::Spec->catfile( $filepath, $filename );

   my $bytes = $fmgr->put_data( $part->body, $fullpath );
            my $cidtom = $part->header('Content-Id');
#TK using cidtom not cid since cid used elsewhere
            if ($cidtom) {
                $cidtom =~ s/^<|>$//g;
            }

   my $file  = {
                  name       => $filename,
                  path       => $fullpath,
                  url        => $urlpath . $filename,
                  media_type => $media_type,
                  size       => $bytes,
                  content_id => $cidtom,
               };
   my $asset = $pkg->save_attachment( $blog, $file );
#TK When it's an iPhone video, media_type = video/quicktime
   my $posttext = '';

   if ($asset) {
      $file->{asset_id}    = $asset->id;
      $file->{asset_class} = $asset->class;
      $file->{asset} = $asset; #TK Added
      push @files, $file; #TK Added. 
      if ($file->{media_type} =~ /^image/) {
         # Image - Check if need to autorotate it
         my $exifTool = new Image::ExifTool;
         my $imageinfo = $exifTool->ImageInfo($file->{path}); # get EXIF data from source

         if (!exists $imageinfo->{ERROR}) {
            my $autorotate = { rotation => 0 };

            my $is_iphone  = 0;
            my $software   = 0;

            foreach my $key (%{$imageinfo}) {
               next if $autorotate->{rotation} != 0;

               if ($key =~ m/(?:Orientation|AutoRotate)/i && $imageinfo->{$key} =~ m/Rotate (\d+)\s*(CW|CCW)?/i) {
                  my $rotation  = $1;
                  my $direction = $2 || 'CW';
                  $rotation = 360 - $rotation if $direction eq 'CCW';
                  $autorotate = {
                                   rotation => $rotation,
                                   exifkey  => $key,
                                } if $rotation =~ m/(?:90|180|270)/;
               }

               if ($key =~ m/Software/ && $imageinfo->{$key} =~ m/^(\d.)+$/) {
                  $software = $1;
               }

               if ($key =~ m/Model/ && $imageinfo->{$key} =~ m/^iPhone/) {
                  $is_iphone = 1;
               }
            }

            if ($autorotate->{rotation}) {
               # open the source image
               my $img = Image::Magick->new();
               $img->Set(debug=>'No'); # No, Configure, Annotate, Render, Locale, Coder, X11, Cache, Blob, All
               my $geterror = $img->Read("$file->{path}\[0\]"); # [0] in case there is also a preview image in the jpg

               # check for errors
               my ($errorlevel) = $geterror =~ /(\d+)/;

               if ((defined $errorlevel && $errorlevel < 399) || !defined $errorlevel) {
                  # apply auto-rotation
                  $img->Rotate(degrees=>$autorotate->{rotation});
                  $img->Write(filename=>$file->{path}, compression=>'JPEG', quality=>99);
               }
            }

            # update Orientation EXIF on autorotated images
            if ($autorotate->{rotation}) {
               $exifTool->SetNewValue($autorotate->{exifkey}, "Horizontal (normal)");
               $exifTool->WriteInfo($file->{path});
            }
         #}
#TK Start image resize
#Check image size and resize if >max_image-width defined on per-blog basis
my $img2=Image::Magick->new;
$img2->Read($file->{path});

#Get Dimensions
my ($globe_x, $globe_y) = imgsize($file->{path});
## added this to debug a divide by zero, but problem is the globe vars 'sometimes' can't figure out image size. 
$globe_y=$globe_y+1; # so don't get divide by zero error.
my $ratio = 0;
# Now set ratio = to the width you want

# If landscape set ratio (width) to max_image_width, else if portrait - set to 450
#if ($globe_x > $globe_y) {
#  $ratio=$cfgglobal->{max_image_width}; #TK Get blog-level max image width
#} else {
#  $ratio=450; #Portrait image, so make slightly narrower [can set to max_image_width if you want]
#}

$ratio=$cfgglobal->{max_image_width}; #TK Get blog-level max image width

my $ratio2 = ($ratio / $globe_x) * $globe_y;
# IGNORE Start
#Actually sometimes small images might occur, so let's override the ratio
#by testing if image with is smaller than 600px. if so don't resize
#if (($globe_y < 1280) || ($globe_x < 600)){ # Can also test height, but skipping this for now.
#if (($globe_x < 600)){
#  }else{
# IGNORE End

# Ignoring above if statement & sticking with max_image_width instead
if (($globe_x < $ratio)){
  }else{
	#Above leaves image alone - no resize. Else does resize here:
	$img2->Resize(width=>$ratio, height=>$ratio2);
	#Here is where it writes the resized image
     	$img2->Write(filename=>$file->{path}, compression=>'JPEG', quality=>75);
       }
         } #End If image
         # TK Orig. Removing Form $posttext = qq|<form contenteditable="false" mt:asset-id="$file->{asset_id}" class="mt-enclosure mt-enclosure-$file->{asset_class}" style="display: inline;">| .
         $posttext = qq|<img alt="" src="$file->{url}" class="mt-image-none" style="" />|; 
      } else {
         #TK Orig. Removing Form $posttext .= qq|<form contenteditable="false" mt:asset-id="$file->{asset_id}" class="mt-enclosure mt-enclosure-$file->{asset_class}" style="display: inline;">|;
         # Not needed after removing Form text $posttext .= qq||;
         $posttext .= qq|<a href="$file->{url}">$file->{name}</a>|;
      #TK Not needed   $posttext .= qq|</form>|;
      } #Close If asset is image
      if ($file->{media_type} =~ /^video/) {
         $posttext = qq|<br><script src=\"http:\/\/blog.tmcnet.com\/inc\/AC_QuickTime.js\" language=\"JavaScript\" type=\"text\/javascript\"><\/script> <script language=\"javascript\"> QT_WriteOBJECT('$file->{url}', '590','443', '', 'autoplay', 'false', 'bgcolor', 'white', 'scale', 'aspect'); <\/script><br><i>Double Click Video Above to Play</i>|;
      }

   } #Close If asset

   return $posttext;
}

sub process_text_part {
   # given a message part that is text/plain|html|enriched,
   # sanitize, encode, and return the post text
   my ($pkg, $blog, $msg, $charset, $media_type, $part) = @_;

# MUST DETECT type AND then only tranform if it's plaintext
my $htmltrue = 0;
my $body;
        if ($media_type =~ m!^text/(html|plain)!) 
        {
            $body = MT::I18N::encode_text($part->body, $charset);

            if ($media_type eq 'text/plain') {
            # we're embedding plain text email so convert to HTML
            # so we can preserve line breaks in iPhone, Outlook PlainText email, etc.
              $body = html_text_transform($body);
              $htmltrue = 1;
            }
        } 
my $text;

if ($htmltrue == 1) {
  $text .= $body;
} else {
      $text = $part->body;
       }
  
   # TBD: Allow user to specify the sanitize spec for this

# TK Took out div tag since Outlook surrounds email with <div> forcing entry down 1 line. If you need <div> tags add it to HTML tags below.
   require MT::Sanitize;
   $text = MT::Sanitize->sanitize($text,
        "a href rel,b,i,strong,em,p,br/,ul,li,ol,blockquote,pre,span,table,tr,th rowspan colspan,td rowspan colspan,dd,dl,dt,img height width src alt");
   my $posttext = $text;
   require MT::I18N;
   $posttext = MT::I18N::encode_text( $posttext, $charset );

   return $posttext;
}

sub process_message_parts {
    my $pkg = shift;
    my ( $blog, $msg ) = @_;
#    my ( $blog, $msg, $author) = @_; #TK from v1.1

    $msg->{is_html} = 0;

    my $parsed = Email::MIME->new( $msg->{message} );

    my @parts = $parsed->parts;
    my $charset = '';

    for(my $i = 0; $i < scalar @parts; $i++) {
       # skip the plain text part if it is immediately followed by an html version of itself
       if (
             $parts[$i]->content_type =~ m#^text/plain#
             && $i + 1 < scalar @parts
             && $parts[$i + 1]->content_type =~ m#^text/html#
          ) {
          $msg->{is_html} = 1;
          next;
       }

       convert_part_to_posttext($pkg, $blog, $msg, $charset, $parts[$i]);
    }

    require MT::I18N;
    $msg->{subject} = MT::I18N::encode_text( $parsed->header("Subject"), $charset );
#TK Added these lines here since line above is keeping the [Category name] and hash tags in there. Need to figure out HOW TO ADD CHARSET for proper encoding
#TK Here is where I could set each blog to use a default category [FUTURE]
$charset = "us-ascii"; #TK Hacked this as local var since couldn't figure out how to get to work by passing this variable.
#Next line pulls out category ($1) and subject ($2), but $2 includes #hashtags, i.e. #tag2,#tag2. But I pull out hashtags from subject later on.
    if ($msg->{subject} =~ m/^[ ]*\[([^\]]+?)\][ ]*(.+)$/) {
        $msg->{category} = MT::I18N::encode_text($1, $charset);
        $msg->{subject} = MT::I18N::encode_text($2, $charset); #Removes [Category] from subject
    }
# Process for #hashtags - remove all #hashtags from Subject
   $msg->{subject} =~ s/#(.[^,]*),*//g;
   $msg->{subject} =~ s/\s+$//; #Remove trailing spaces
   $msg->{subject} = MT::I18N::encode_text($msg->{subject}, $charset);
}

sub convert_part_to_posttext {
   my ($pkg, $blog, $msg, $charset, $part) = @_;

   if ($part->subparts > 0) {
      my @subparts = $part->subparts;

      for(my $i = 0; $i < scalar @subparts; $i++) {
         # skip the plain text subpart if it is immediately followed by an html version of itself
         if (
               $subparts[$i]->content_type =~ m#^text/plain#
               && $i + 1 < scalar @subparts
               && $subparts[$i + 1]->content_type =~ m#^text/html#
            ) {
            $msg->{is_html} = 1;
            next;
         }

         convert_part_to_posttext($pkg, $blog, $msg, $charset, $subparts[$i]);
      }
   } else {
      my ( $media_type, $charset ) = _parse_content_type( $part->header('Content-Type') );
         if ( $media_type =~ m#^text/(?:plain|html|enriched)# ) {
            $msg->{text} .= process_text_part($pkg, $blog, $msg, $charset, $media_type, $part);
      } else {
         if ($part->filename) {
            my $filelink = process_file_part($pkg, $blog, $msg, $charset, $media_type, $part);

            # replace inline cid and loc links to this file
            # note: This only supports images currently, and only if the sanitizer
            # includes "img src" and no other img tag attributes
            my $cid = $part->header('Content-ID') || '';
            my $loc = $part->header('Content-Location') || '';
            $cid =~ s/^<//;
            $cid =~ s/>$//;
            $loc =~ s/^<//;
            $loc =~ s/>$//;

            my $inlined = 0;

            # replace all the content-id (cid:) occurences
            $inlined++ if $cid ne '' && $msg->{text} =~ s#<\s*img\s+src=['"]*(?:cid:)+\Q$cid\E['"]*\s*/?>#$filelink#sig;

            # replace all the content-location occurences
            $inlined++ if $loc ne '' && $msg->{text} =~ s#<\s*img\s+src=(?:cid:|['"])*\Q$loc\E['"]*\s*/?>#$filelink#sig;

            # catch-all ugly hack for strange CIDs
            my $origfilename = $part->filename;

            $inlined++ if (
                             $inlined == 0
                             && defined $msg->{text}
                             && (
                                   $msg->{text} =~ s#<\s*img\s+src=['"]*(?:cid:)+[\d\w\-]+/\Q$origfilename\E['"]*\s*/?>#$filelink#sig
                                   || $msg->{text} =~ s#<\s*img\s+(background|src)\s*=\s*['"][^\s\<\>"']{0,256}?/\Q$origfilename\E['"]\s*/?>#$filelink#sig
                                )
                          );
            # otherwise just append this filelink to the posttext
            $msg->{text} .= $filelink unless $inlined;
         }
      }
   }
}

sub _get_valid_addresses {
    my $pkg = shift;
    my ($blog_id, $cfg) = @_;

    # Get Addresses out of plugindata
    my @addresses = split(/\s*,\s*/, lc($cfg->{allowed_emails} || ''));
    my %addresses;
    $addresses{$_} = 1 for @addresses;

    require MT::Permission;
    require MT::Author;

    # FIXME: This doesn't include any sysadmins who have no direct
    # relationship with the blog...
    if ($cfg->{allow_mt_authors}) {

        # get addresses for this blog
        my $iter = MT::Permission->load_iter({ blog_id => $blog_id, });
        while (my $perm = $iter->()) {
            my $au = MT::Author->load({ id => $perm->author_id });
            if ($au && $au->email) {
                $addresses{ lc $au->email } = $au;
            }
        }
    }
    return \%addresses;
}

sub process_message {
    my $pkg = shift;
    my ( $blog_id, $cfg, $au, $perm, $msg ) = @_;
    my $author = @_; #TK from v1.1 [some vars removed]

    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);

    $pkg->process_message_parts( $blog, $msg );

    require MT::Entry;
    my $entry = MT::Entry->new();
    $entry->title( $msg->{subject} );
    $entry->text( $msg->{text} );
    $entry->author_id( $au->id );
    $entry->blog_id($blog_id);
    $entry->status( $cfg->{post_status} || 1 );
    $entry->tags(@{$msg->{tags}}) if $msg->{tags}; #TK Added
#    $entry->convert_breaks( !$msg->{is_html} );
#The value for the .convert breaks. flag for the entry.
#Valid values are either 0 or 1.
#    0 - raw html
#    1 - convert line breaks to <br />
#    __default__ - will default to the text formatting option specified in blog entry settings
#    markdown_with_smartypants - Markdown with Smartypants
#    markdown - Markdown
#    textile_2 - Textile 2
#    richtext - Rich Text via HTML text editor
# convert_paras = A comma-separated list of text filters to apply to each entry when it is built. Note: I see $blog->convert_paras(1); in Blog.pm file. Possible this converts paragraph marks. Could play with this. Actually I think it defaults to setting it to be same as $default_text_format. Look at mt/lib/MT/Blog.pm
#my $format = $author->text_format || $blog->convert_paras || '__default__';
#    $entry->convert_breaks($msg->{format});
# Assume line breaks for plaintext by setting $textformat='1'
    my $textformat = 'richtext';
# Test to see if HTML and if so, set to richtext
    if ($msg->{is_html} == 1) { 
       $textformat = 'richtext';
    } 
    $entry->convert_breaks($textformat);

    MT->run_callbacks(
        'postoffice_pre_save',
        blog_id     => $blog_id,
        config      => $cfg,
        author      => $au,
        permissions => $perm,
        message     => $msg,
        entry       => $entry,
    );

    print STDERR "Saving entry [" . $entry->title . "]\n"
      if $DEBUG;

    if (! $entry->save) {
        print STDERR "[PostOffice] Error saving entry [" . $entry->title . "]: "
            . $entry->errstr . "\n";
        return 0;
    }
    # create ObjectAsset associations for attachments if they don't already exist
    $msg->{files} = \@files;
    if ($msg->{files}) {
        require MT::ObjectAsset;
        foreach my $file (@{$msg->{files}}) {
            next unless $file->{asset};
            my $asset = $file->{asset};
            my $obj_asset = MT::ObjectAsset->load({ asset_id => $asset->id,
                object_ds => 'entry', object_id => $entry->id });
            unless ($obj_asset) {
                $obj_asset = new MT::ObjectAsset;
                $obj_asset->blog_id($blog_id);
                $obj_asset->asset_id($asset->id);
                $obj_asset->object_ds('entry');
                $obj_asset->object_id($entry->id);
                $obj_asset->save;
            }
        }
    }

    my $cat;
    my $place;
    if ( $msg->{category} ) {
        require MT::Category;
        $cat = MT::Category->load( { label => $msg->{category} } );
        unless ($cat) {
            if ( $perm->can_edit_categories ) {
                $cat = MT::Category->new();
                $cat->blog_id($blog_id);
                $cat->label( $msg->{category} );
                $cat->parent(0);
                $cat->save
                  or die $cat->errstr;
            }
        }

        if ($cat) {
            require MT::Placement;
            $place = MT::Placement->new;
            $place->entry_id( $entry->id );
            $place->blog_id($blog_id);
            $place->category_id( $cat->id );
            $place->is_primary(1);
            $place->save
              or die $place->errstr;
        }
    }

    MT->run_callbacks(
        'postoffice_post_save',
        blog_id     => $blog_id,
        config      => $cfg,
        author      => $au,
        permissions => $perm,
        message     => $msg,
        entry       => $entry,
        ( $cat   ? ( category  => $cat )   : () ),
        ( $place ? ( placement => $place ) : () ),
    );

    if ( $entry->status == 2 ) {    # publish
        MT->rebuild_entry(
            Entry             => $entry,
            BuildDependencies => 1,
        );
    }

    MT->run_callbacks( 'api_post_save.entry', MT->instance, $entry, undef );

    1;
}

sub process_messages {
    my $pkg = shift;
    my ( $blog_id, $cfg ) = @_;

    my $app = MT->app;
    if ( $app->isa('MT::App') ) {
        $blog_id ||= $app->param('blog_id');
    }

    $cfg ||= $blog_id ? $pkg->plugin->get_config_hash('blog:' . $blog_id) : $pkg->plugin->get_config_hash();

    require MT::Author;
    my $default_author_id = $cfg->{default_author};
    my $default_author = MT::Author->load($default_author_id)
      if $default_author_id;

    $cfgglobal = $cfg;
    my $xp = $pkg->transport($cfg)
      or die "PostOffice: No mail transport configured";
    my $iter = $xp->message_iter or return 0;

    my $count = 0;

    my $max_image_width = $cfg->{max_image_width}; #TK Max Image Width per blog
    my $addresses_by_blog = {};

    while ( my $msg = $iter->() ) {
        # determine blog_id for active message
        my $extension = $msg->{to};
        my $api_key;
        my $local_blog_id = $blog_id;
        if ( $extension =~ m/^[^@]+\+(.+?)@/ ) {
            $extension = $1;
            if ( $extension =~ m!^(?:(.+)\.)?(\d+)$! ) {
                $local_blog_id = $2;
                $api_key = $1 if $1;
            }
            else {
                $api_key = $extension;
            }
        }
        else {
            $extension = undef;
        }
        if ( !$local_blog_id ) {
            print STDERR "PostOffice: No blog_id parameter present for message "
              . $msg->{'message-id'}
              . " from "
              . $msg->{from} . "\n";
        }

        my $addresses = $addresses_by_blog->{$local_blog_id} ||=
          $pkg->_get_valid_addresses( $local_blog_id, $cfg );

        my ($addr) = Email::Address->parse( $msg->{from} );
        if ( !$addr ) {
            print STDERR "PostOffice: error parsing 'from' address for message "
              . $msg->{'message-id'}
              . " from "
              . $msg->{from} . "\n";
            next;
        }
        my $from = lc $addr->address;
#Error out print STDERR "\n addresses->from:" . $addresses->{$from};
        unless ( $addresses->{$from} ) {
            print STDERR "\n PostOffice: Unknown author address for message "
              . $msg->{'message-id'}
              . " from "
              . $msg->{from} . "\n";
            next;
        }
        my $au =
          ref $addresses->{$from}
          ? $addresses->{$from}
          : MT::Author->load( { email => $from } );
        $au ||= $default_author;
        if ( !$au ) {
            print STDERR "PostOffice: No MT author found for message "
              . $msg->{'message-id'}
              . " from "
              . $msg->{from} . "\n";
            next;
        }

        # Test for API key requirement
        if ( $cfg->{require_api_key} ) {
            if ( !$api_key ) {

                # TBD: Log API key missing message??
                print STDERR "PostOffice: Missing API key for message "
                  . $msg->{'message-id'}
                  . " from "
                  . $msg->{from} . " to "
                  . $msg->{to} . "\n";
                next;
            }

            # TBD: Log incorrect API key?
##TK Making Global            require MT::Util;
            if (
                $api_key
                && (perl_sha1_digest_hex( $au->api_password ) ne
                    $api_key )
              )
            {
                print STDERR "PostOffice: Invalid API key for message "
                  . $msg->{'message-id'}
                  . " from "
                  . $msg->{from} . " to "
                  . $msg->{to} . "\n";
                next;
            }
        }

        require MT::Permission;
        my $perm =
          MT::Permission->load(
            { author_id => $au->id, blog_id => $local_blog_id } );
        next unless $perm;

        $au->is_superuser || $perm->can_administer_blog || $perm->can_post
          or next;

my $fullsubject;

    # Save full $msg->{subject} since needed for #tag parsing
    $fullsubject = $msg->{subject};

    # Process for #hashtags.
    #3/27/12 Added support for spaced tags using comma delimeter.
    # Format: #ip communications,#the hunger games,#star wars
    if ($fullsubject =~ m/#/) {
        # OLD Space delimiter - my @tags = $msg->{subject} =~ m/#(\D[^ ]*)\s*/g;
        my @tags = $fullsubject =~ m/#(\D[^,]*),*/g;
        if (@tags) {
            $msg->{tags} = [];
            foreach my $tag (@tags) {
#                push @{$msg->{tags}}, MT::I18N::encode_text($tag, $charset);
                push @{$msg->{tags}}, $tag;
            }
            #$msg->{subject} =~ s/#(\D[^ ]*)\s*//g;
            #$msg->{subject} =~ s/#(\D[^,]*),*//g;
            #$msg->{subject} =~ s/\s+$//;
        }
    }


        if ( $pkg->process_message( $local_blog_id, $cfg, $au, $perm, $msg ) ) {
            $xp->remove($msg);
            $count++;
        }
    }

    $count;
}

sub transport {
    my $pkg            = shift;
    my ($cfg)          = @_;
    my $transport      = lc( $cfg->{email_transport} ) || 'pop3';
    my $all_transports = MT->registry("postoffice_transports");
    my $tp             = $all_transports->{$transport};
    my $label          = $tp->{label};
    $label = $label->() if ref($label);
    my $class = $tp->{class} if $tp;
    $class ||= 'PostOffice::Transport::POP3';
    eval qq{require $class; 1;}
      or die "PostOffice: failed to load transport class $class";

    print "Connecting to " . $label . " server " . $cfg->{email_host} . "...\n"
      if $DEBUG;

    my %param = (
        %$cfg,
        username => $cfg->{email_username},
        password => $cfg->{email_password},
        host     => $cfg->{email_host},
        ssl      => $cfg->{use_ssl},
    );

    $class->new(%param);
}

1;
