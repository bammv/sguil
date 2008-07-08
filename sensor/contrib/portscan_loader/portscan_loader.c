/*
 * Copyright (C) 2003 SecureCiRT Pte Ltd (Singapore)
 *
 * Author(s):
 *  Jeffrey Lim <jeffrey.lim@securecirt.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <stdio.h>
#include <getopt.h>

#include <dirent.h>
#include <string.h>

#define MAXDIR 1024
#define BUFSIZE 4096

int verbose, sleepS;
char *arcdir;
char *dir;
char *ip;
int port;

char buffer[BUFSIZE];


void
showUsage (void)
{
  printf ("Usage: portscan_loader [options] ip port\n\n");
  printf ("Options:\n");

  printf
    ("\t-q, --quiet\n\t\tRun in quiet mode (Verbose is default; overrides all verbosity settings)\n\n");
  printf ("\t-v, --verbose\n\t\tMore verbosity\n\n");
  printf
    ("\t-1, --runonce\n\t\tRun once and exit - do not run in daemon mode\n\n");
  printf
    ("\t-d D\n\t\tSpecify Directory where portscan logfiles are kept\n\n");
  printf
    ("\t-a D, --archive D\n\t\tSpecify Directory where portscan logfiles are to be archived to\n\n");
  printf
    ("\t-s N, --sleep N\n\t\tSleep for N seconds (*DEFAULT 10 seconds*)\n\n");
}


int
main (int argc, char **argv)
{

  int once = 0;

  int err = 0;
  char c;

  if (argc == 1)
    {
      showUsage ();
      exit (0);
    }

  sleepS = 10;
  verbose = 1;
  dir = 0;
  arcdir = 0;
  while (1)
    {
      int option_index = 0;
      static struct option long_options[] = {
	{"quiet", 0, 0, 'q'},
	{"verbose", 0, 0, 'v'},
	{"dir", 1, 0, 'd'},
	{"sleep", 1, 0, 'z'},
	{"archive", 1, 0, 'a'},
	{"runonce", 0, 0, '1'},
	{0, 0, 0, 0}
      };

      c = getopt_long (argc, argv, "1a:vqd:s:", long_options, &option_index);
      if (c == -1)
	break;

      switch (c)
	{
	case 'a':
	  arcdir = optarg;
	  break;

	case 'q':
	  verbose = 0;
	  break;

	case 'v':
	  verbose++;
	  break;

	case 'd':
	  dir = optarg;
	  break;

	case '1':
	  once = 1;
	  break;

	case 's':
	  sleepS = atoi (optarg);
	  break;

	case '?':
	  err = 1;
	  break;
	}
    }

  if (err)
    {
      showUsage ();
      exit (1);
    }
  else if (!dir)
    {
      fprintf (stderr,
	       "Directory location for portscan log files not specified!\n");
      fprintf (stderr, "- use the '-d' switch\n\n");
      exit (1);
    }
  else if (!arcdir)
    {
      fprintf (stderr, "sooo... no archival options, ay?\n");
      fprintf (stderr, "bah! humbug! ");
      fprintf (stderr, "(use the '-a' switch)\n\n");
      exit (1);
    }

  if (!argv[optind++] || !argv[optind])
    {
      fprintf (stderr,
	       "Have you specified the ip and port to connect to?\n\n");
      exit (1);
    }

  port = atoi (argv[optind--]);
  ip = argv[optind];

  run (argv[0]);
  strcpy (dir, ".");
  if (once)
    exit (0);

  while (1)
    {
      sleep (sleepS);
      run (argv[0]);
    }
}


/* slight difference between scripts/portscan_loader.tcl and this C code - whereas the tcl code CLOSES the socket
   for every file send, this one will only close it after ALL the files in the specified dir
   have been sent over! Then it will just sleep for the specified amount of time and then
   read the dir again to see if any new files have appeared, and send these over as well.... */

int
run (char *progname)
{

  extern int errno;

  int sockfd, len;
  struct sockaddr_in addr;

  DIR *d;
  FILE *f;
  struct dirent *entry;
  struct stat statbuf;

  /* ----------------------------------------------------------------
   *  Error checking first
   * ---------------------------------------------------------------- */

  if (verbose >= 2)
    printf ("performing error checking...\n\n");

  if (!(d = opendir (dir)))
    {
      fprintf (stderr, "Failed to open directory '%s'\n\n", dir);
      perror (progname);
      exit (1);
    }

  if (chdir (dir))
    {
      fprintf (stderr, "Hm. can't change dir to directory '%s'\n", dir);
      fprintf (stderr, "pteui!! exitting...\n\n");
      exit (1);
    }

  sockfd = socket (AF_INET, SOCK_STREAM, 0);

  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = inet_addr (ip);
  addr.sin_port = htons (port);
  len = sizeof (addr);

  while (1)
    {
      if (connect (sockfd, (struct sockaddr *) &addr, len) == -1)
	{
	  fprintf (stderr, "can't connect to server! sleeping 5 secs...\n");
	  sleep (5);
	}
      else
	break;
    }
  if (verbose >= 2)
    printf ("connected to %s:%d\n\n", ip, port);

  /* ---------------------------------------------------------------- */


  int archiveerr = 0;

  while ((entry = readdir (d)) != NULL)
    {

      lstat (entry->d_name, &statbuf);
      if (S_ISDIR (statbuf.st_mode))
	continue;

      if (!strncmp ((const char *) entry->d_name, "portscan_log.", 13))
	{

	  if (verbose >= 2)
	    printf ("sending string 'PSFILE %s' over...\n", entry->d_name);

	  write (sockfd, "PSFILE ", 7);
	  write (sockfd, entry->d_name, strlen (entry->d_name));
	  write (sockfd, "\n", 1);

	  /* now send actual file over */

	  if (verbose)
	    {
	      printf ("sending FILE '%s' over...", entry->d_name);
	      fflush (stdout);
	    }

	  if (!(f = fopen (entry->d_name, "rb")))
	    {
	      fprintf (stderr, "\nFailed to open '%s'??\n", entry->d_name);
	      perror (progname);
	      errno = 0;
	      continue;
	    }

	  while (len = fread (buffer, sizeof (char), BUFSIZE, f))
	    write (sockfd, buffer, len);

	  if (ferror (f))
	    {
	      fprintf (stderr, "Error occurred with file '%s'\n",
		       entry->d_name);
	      continue;
	    }
	  else
	    printf ("  done.\n");

	  if (verbose)
	    printf ("archiving FILE '%s' to %s/...\n", entry->d_name, arcdir);

	  if (snprintf
	      (buffer, sizeof (buffer), "mv %s %s/ 2>&1", entry->d_name,
	       arcdir) >= sizeof (buffer))
	    {
	      fprintf (stderr, "hm, filename/directory name too long?\n");
	      fprintf (stderr, "not archiving...\n\n");
	      archiveerr = 1;
	    }
	  else
	    {

	      /* ------- attempt archival operation ------- */

	      FILE *read_fp;

	      if ((read_fp = popen (buffer, "r")) < 1)
		{
		  perror (progname);
		  archiveerr = 1;
		  errno = 0;
		}
	      else
		{
		  buffer[0] = 0;
		  len = fread (buffer, sizeof (char), BUFSIZE, read_fp);
		  if (ferror (read_fp))
		    {
		      fprintf (stderr, "Error in archival operation??\n");
		      archiveerr = 1;
		    }
		  else if (len)
		    {
		      buffer[len] = 0;
		      fprintf (stderr, progname);
		      fprintf (stderr, ": ");
		      fprintf (stderr, buffer + 4 * sizeof (char));
		      archiveerr = 1;
		    }
		}
	    }
	}

      else if (verbose >= 2)
	printf ("    skipping unknown/unmatched file '%s'\n", entry->d_name);

    }

  if (errno)
    perror (progname);		/* error from readdir() */
  if (verbose)
    printf ("\nclosing connection to %s:%d\n\n", ip, port);


  close (sockfd);
  closedir (d);

  if (verbose >= 2)
    printf ("-----\n\n");

  if (archiveerr)
    {
      fprintf (stderr, "archival operation not successful!\n");
      fprintf (stderr, "Files were sent but not archived..\n");
      fprintf (stderr,
	       "Exitting so as not to resend the log files. Please do the archival operation yourself...\n\n");
      exit (1);
    }

}
