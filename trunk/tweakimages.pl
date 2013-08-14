#!/usr/bin/perl
use strict;
use Storable;
use Data::Dumper;
use URI::Escape;
use POSIX qw(strftime);
use File::Basename;
use File::Path qw(make_path);
use Digest::MD5::File qw( file_md5_hex );
use File::Copy;

my $originaldir="/opt/ppcontent/ppstatic";
my $webpdir="/opt/ppcontent/ppstaticwebp";
my $optimizeddir="/opt/ppcontent/ppstaticoptimized";

my $logshashfile="logs.hash";
my %loghash=%{retrieve($logshashfile)};

my $orighashfile="originalfile.hash";
store {}, $orighashfile unless -r $orighashfile;
my %orighash=%{retrieve($orighashfile)};

my $opthashfile="optimizedfile.hash";
store {}, $opthashfile unless -r $opthashfile;
my %opthash=%{retrieve($opthashfile)};

my $webphashfile="webpfile.hash";
store {}, $webphashfile unless -r $webphashfile;
my %webphash=%{retrieve($webphashfile)};

  if ($ARGV[0]) {
    processfile($ARGV[0]);
  } else {
    foreach my $key ( keys %loghash ){
      if ($loghash{$key} > (time - (1*24*60*60))) {
       processfile($key);
      }
    }
  }


sub processfile {
my $file=$_[0];
my $ppcontentpath= substr $file, index($file, 'ppcontent');
my $safename= uri_unescape($ppcontentpath);

if (-f $safename) {
  print "reading $safename\n";
my $ppnewcontentpath=uri_unescape(substr $file, (index($file, 'ppcontent')+18));
  my($filename, $directory, $suffix) = fileparse($ppnewcontentpath,qr/\.[^.]*/);
  my $webpcommand;
  my $filehash=file_md5_hex( $safename );
 if ($orighash{$safename} != $filehash ||!$orighash{$safename})  {
# original file has new md5sum, so do stuff
    $orighash{$safename}=$filehash ;
    if (! -d $webpdir . $directory) {
      make_path($webpdir . $directory);
    }

    if (! -d $optimizeddir . $directory) {
      make_path($optimizeddir . $directory);
    }
# convert to webp, two commands as some jpegs are saved as gif's
    if (($suffix =~ /.png/) || ($suffix =~ /.jpeg/) || ($suffix =~ /.jpg/)) {
      $webpcommand1 = '/opt/imagebin/bin/cwebp -short -mt';
      $webpcommand2 = '/opt/imagebin/bin/gif2webp';
    }

    if ($suffix =~ /.gif/) {
      $webpcommand1 = '/opt/imagebin/bin/gif2webp';
      $webpcommand2 = '/opt/imagebin/bin/cwebp -short -mt';
    }
    if ($webpcommand1) {
      if (system($webpcommand1 . ' "' . $safename . '" -o "' . $webpdir . $directory . $filename . $suffix . '"') != 0) {
        if (system($webpcommand2 . ' "' . $safename . '" -o "' . $webpdir . $directory . $filename . $suffix . '"') != 0) {
          #conversion failed, copy the original then
          print 'Copying File as Conversion failed :' .  $safename;
          copy($safename,$webpdir . $directory);
        }
      } else {
        $webphash{$safename}=file_md5_hex($webpdir . $directory . $filename . $suffix);
      }
       
      # optimize existings images, don't convert 
      if (system( '/opt/imagebin/bin/optimize_image_bin -input_file="' . $safename . '" -output_file "' . $webpdir . $directory . $filename . $suffix . '"') != 0) {
        print 'Copying File as Optimization failed :' .  $safename;
          copy($safename,$optimizeddir . $directory);
      } else {
          $opthash{$safename}=file_md5_hex($optimizeddir . $directory . $filename . $suffix);
      }
   }
  
}
}
}

store \%orighash, $orighashfile;
store \%opthash, $opthashfile;
store \%webphash, $webphashfile;

