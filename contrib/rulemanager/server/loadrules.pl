#!/usr/bin/perl
# Author: Mark Vevers
# Version: 0.0.1a
# --------------------------------------------------------------------------
# Copyright (C) 2002 Mark Vevers <mark@vevers.net>
#
# Modifications made by Michael Boman, SecureCiRT Pte Ltd (Singapore)
#    <michael.boman@securecirt.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# --------------------------------------------------------------------------
# Syntax loadrules.pl <Rule Directory>
# --------------------------------------------------------------------------
# Database configuration
$dbname   = "sguildb";
$dbuser   = "dbuser";
$dbpass   = "dbpass";
$dbserver = "localhost";

# --------------------------------------------------------------------------
use DBI;

$ruledir = $ARGV[0];

opendir RDIR, $ruledir || die ("Can't open rules dir");
$dbh =
  DBI->connect( "DBI:mysql:" . $dbname . ":" . $dbserver, $dbuser, $dbpass );

while ( $dirent = readdir RDIR ) {
    R_FILES: {
        $dirent =~ /^(\S+)\.rules$/ && do {
            &loadrules( $ruledir, $1, $dbh );

            last R_FILES;
        };
    }
}

closedir RDIR;
$result = $dbh->disconnect;
exit(0);

sub loadrules {
    my $dir     = $_[0];
    my $ruleset = $_[1];
    my $dbh     = $_[2];
    my $file    = $dir . '/' . $ruleset . ".rules";

    if ( -e $file ) {

        print "Ruleset: $ruleset\n";
        open RULES, $file || die ("Couldn't open ruleset $ruleset");
        $rgid = &getrulesetid( $ruleset, $dbh );
        while (<RULES>) {
            R_RULES: {
/^(drop|alert|log|pass|activate|dynamic)\s+(\S+?)\s+(\S+?)\s+(\S+?)\s+(\S+?)\s+(\S+?)\s+(\S+?)\s+\((.*)\)$/
                  && do {
                    (
                        $action, $proto, $s_ip,   $s_port,
                        $dir,    $d_ip,  $d_port, $options
                      )
                      = ( $1, $2, $3, $4, $5, $6, $7, $8 );
                    $rule = $_;

                    $options =~ /msg:\s*\"(.*?)\"/;
                    $rname = $1;

                    $options =~ /sid:\s*(\d+?)\s*;/;
                    $rid = $1;

                    $options =~ /rev:\s*(\d+?)\s*;/;
                    $rev = $1;

                    $sql1 =
                      $dbh->prepare("SELECT rev FROM rman_rules WHERE rid = ?");
                    $sql1->execute($rid);

                    if ( $sql1->rows == 0 ) {
                        $sql2 =
                          $dbh->prepare(
"INSERT INTO rman_rules (rid,rev,name,active,created,action,proto,s_ip,s_port,dir,d_ip,d_port,options) VALUES (?, ?, ?, 'Y', NULL,?,?,?,?,?,?,?,?)"
                          );
                        $sql2->execute(
                            $rid,   $rev,    $rname,  $action,
                            $proto, $s_ip,   $s_port, $dir,
                            $d_ip,  $d_port, $options
                        );
                        $sql2->finish;
                        $sql2 =
                          $dbh->prepare(
                            "INSERT INTO rman_rrgid (rid,rgid) VALUES (?, ?)");
                        $sql2->execute( $rid, $rgid );
                        $sql2->finish;
                        &Rule_UpdateTimeStamp( $dbh, $rid );
                        $new = "new";
                        print "Rule $rid: $new, $rname\n";
                    }
                    else {
                        ($oldrev) = $sql1->fetchrow_array;
                        if ( $oldrev < $rev ) {
                            $new  = "Updated";
                            $sql2 =
                              $dbh->prepare(
"UPDATE rman_rules SET rev=?, name=?, action=?, proto=?, s_ip=?, s_port=?, dir=?, d_ip=?, d_port=?, options=? WHERE rid=?"
                              );
                            $sql2->execute(
                                $rev,    $rname,   $action, $proto,
                                $s_ip,   $s_port,  $dir,    $d_ip,
                                $d_port, $options, $rid
                            );
                            $sql2->finish;
                            &Rule_UpdateTimeStamp( $dbh, $rid );
                            print "Rule $rid: $new, $rname\n";
                        }
                        else {
                            $new = "existing";
                        }
                    }
                    $sql1->finish;

                    last R_RULES;
                  };
            }
        }
    }
    close RULES;
}

sub getrulesetid {
    my $rset = $_[0];
    my $dbh  = $_[1];
    my $rgid = 0;

    $sql1 = $dbh->prepare("SELECT rgid FROM rman_rgroup WHERE name = ?");
    $sql1->execute($rset);

    if ( $sql1->rows == 0 ) {
        $sql2 =
          $dbh->prepare(
            "INSERT INTO rman_rgroup (name,description) VALUES (?,?)");
        $sql2->execute( $rset, $rset );
        $rgid = $sql2->{'mysql_insertid'};
        $sql2->finish;
    }
    else {
        ($rgid) = $sql1->fetchrow_array;
    }

    $sql1->finish;
    return ($rgid);
}

sub Rule_UpdateTimeStamp {
    my $dbh = $_[0];
    my $rid = $_[1];
    my $sensor;

    $sql =
      $dbh->prepare(
"SELECT sid FROM rman_senrgrp, rman_rrgid, rman_rules WHERE rman_senrgrp.rgid=rman_rrgid.rgid AND rman_rules.active='Y' AND  rman_rrgid.rid = ? GROUP BY sid"
      );
    $sql->execute($rid);

    if ( $sql->rows != 0 ) {
        $sql1 =
          $dbh->prepare("UPDATE rman_sensor SET updated = NULL WHERE sid = ?");
        while ( ($sensor) = $sql->fetchrow_array ) {
            $sql1->execute($sensor);
        }
        $sql1->finish;
    }
    $sql->finish;
}
