/*
 * Copyright (C) 2003 SecureCiRT Pte Ltd (Singapore)
 *
 * Authors:
 *  Michael Boman <michael.boman@securecirt.com>
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
 
 #include "config.h"

extern int run_command_after_updating (void);
extern int config_test (void);
extern int updated (int sid);
extern int outputvars (int sid);
extern int outputrules (int sid);

extern MYSQL *mysql;

struct sguil_rule_opts myopts;

void
ShowUsage (void)
{
  printf ("Usage: sguil_extractrules [options]\n\n");
  printf ("Options:\n");
  printf
    ("\t-D | --daemon\n\t\tDo a infinite loop (good if you run this under daemontools or inittab\n\n");
  printf
    ("\t-i | --inetd\n\t\tRun once (default). Suitable if you run this under inetd, or want to run it manually\n\n");
  printf
    ("\t-v | --verbose\n\t\tBe verbose (use multiple times to be even more verbose)\n\n");
  printf
    ("\t-q | --quiet\n\t\tBe less verbose (use multiple times to be even less verbose)\n\n");
  printf ("\t-S <num> | --sid <num>\n\t\tUse sensor ID number <num>\n\n");
  printf
    ("\t-s <num> | --update-sidmap \n\t\tUpdate sid-msg.map after downloading new rules\n\n");
  printf
    ("\t-f <num> | --update-filter \n\t\tUpdate filter.bpf after downloading new rules\n\n");
  printf
    ("\t-d <directory> | --dir <directory>\n\t\tStore configuration files under <directory>\n\n");
  printf
    ("\t-u <username> | --dbuser <username>\n\t\tConnect to DB as <user>\n\n");
  printf
    ("\t-p <password> | --dbpass <password>\n\t\tConnect to DB using password <password>\n\n");
  printf
    ("\t-n <database> | --dbname <database>\n\t\tConnect to DB <database>\n\n");
  printf
    ("\t-h <server> | --dbhost <server>\n\t\tConnect to database server <server>\n\n");
  printf
    ("\t-P <port> | --dbport <port>\n\t\tPort number to use for connection\n\n");
  printf
    ("\t-z <seconds> | --sleep <seconds>\n\t\tSleep for <seconds> seconds (when running in daemon mode)\n\n");
  printf
    ("\t-b <snortbin> | --snortbin <snortbin>\n\t\tWhere does snort lives?\n\n");
  printf
    ("\t-a <snortargs> | --snortargs <snortargs>\n\t\tWhat parameters shall we give snort?\n\n");

  printf ("\t-? | --help\n\t\tDisplays this help text\n\n");
}

int
init_config (void)
{
  myopts.verbose = 0;
  myopts.daemon = 0;
  myopts.update_sidmap = 0;
  myopts.update_filter = 0;

  snprintf (myopts.config_dir, sizeof (myopts.config_dir), "/etc/snort");

  snprintf (myopts.db_name, sizeof (myopts.db_name), "sguildb");
  snprintf (myopts.db_host, sizeof (myopts.db_host), "localhost");
  myopts.db_port = 3306;

  snprintf (myopts.snort_bin, sizeof (myopts.snort_bin), "snort");
  snprintf (myopts.snort_opts, sizeof (myopts.snort_opts),
            "-c %s/snort.conf", myopts.config_dir);

  snprintf (myopts.command, sizeof (myopts.command), "killall -HUP snort");
  myopts.sleep_time = 5;
}

int
print_config (void)
{
  printf ("config daemon: %d\n", myopts.daemon);
  printf ("config sensor: %d\n", myopts.sid);
  printf ("config directory: %s\n", myopts.config_dir);
  printf ("config dbuser: %s\n", myopts.db_user);
  printf ("config dbpass: %s\n", myopts.db_pass);
  printf ("config dbname: %s\n", myopts.db_name);
  printf ("config dbhost: %s\n", myopts.db_host);
  printf ("config dbport: %d\n", myopts.db_port);
  printf ("config sleep: %d\n", myopts.sleep_time);
  printf ("config snortbin: %s\n", myopts.snort_bin);
  printf ("config snortargs: %s\n", myopts.snort_opts);
  printf ("config update-sidmap: %d\n", myopts.update_sidmap);
  printf ("config update-filter: %d\n", myopts.update_filter);
}

int
main (int argc, char *argv[])
{
  /*
   * Get the command line parameters
   */

  int err = 0;
  int c;
  int digit_optind = 0;

  init_config ();

  while (1)
    {
      int this_option_optind = optind ? optind : 1;
      int option_index = 0;
      static struct option long_options[] = {
        {"daemon", 0, 0, 'D'},
        {"inetd", 0, 0, 'i'},
        {"verbose", 0, 0, 'v'},
        {"quiet", 0, 0, 'q'},
        {"sid", 1, 0, 'S'},
        {"dir", 1, 0, 'd'},
        {"dbuser", 1, 0, 'u'},
        {"dbpass", 1, 0, 'p'},
        {"dbname", 1, 0, 'n'},
        {"dbhost", 1, 0, 'h'},
        {"dbport", 1, 0, 'P'},
        {"update-sidmap", 0, 0, 's'},
        {"update-filter", 0, 0, 'f'},
        {"snortbin", 1, 0, 'b'},
        {"snortargs", 1, 0, 'a'},
        {"sleep", 1, 0, 'z'},
        {"help", 0, 0, '?'},
        {0, 0, 0, 0}
      };

      c =
        getopt_long (argc, argv, "DivqS:sfd:u:p:n:h:P:z:", long_options,
                     &option_index);
      if (c == -1)
        break;

      switch (c)
        {
        case 'D':
          myopts.daemon = 1;
          break;

        case 'v':
          myopts.verbose++;
          printf ("+verbosity1 - config verbose %d\n", myopts.verbose);
          break;

        case 'q':
          if (myopts.verbose)
            {
              printf ("-verbosity1 - config verbose %d\n",
                      myopts.verbose - 1);
              myopts.verbose--;
            }
          break;

        case 'S':
          myopts.sid = atoi (optarg);
          break;

        case 's':
          myopts.update_sidmap = 1;
          break;

        case 'f':
          myopts.update_filter = 1;
          break;

        case 'd':
          snprintf (myopts.config_dir, sizeof (myopts.config_dir), "%s",
                    optarg);
          snprintf (myopts.timestamp_filename,
                    sizeof (myopts.timestamp_filename), "%s/sguil.timestamp",
                    myopts.config_dir);
          snprintf (myopts.var_filename, sizeof (myopts.var_filename),
                    "%s/sguil.vars", myopts.config_dir);
          snprintf (myopts.rule_filename, sizeof (myopts.rule_filename),
                    "%s/sguil.rules", myopts.config_dir);
          snprintf (myopts.sidfile, sizeof (myopts.sidfile),
                    "%s/sid-msg.map", myopts.config_dir);
          break;

        case 'u':
          snprintf (myopts.db_user, sizeof (myopts.db_user), "%s", optarg);
          break;

        case 'p':
          snprintf (myopts.db_pass, sizeof (myopts.db_pass), "%s", optarg);
          break;

        case 'n':
          snprintf (myopts.db_name, sizeof (myopts.db_name), "%s", optarg);
          break;

        case 'h':
          snprintf (myopts.db_host, sizeof (myopts.db_host), "%s", optarg);
          break;

        case 'P':
          myopts.db_port = atoi (optarg);
          break;

        case 'z':
          myopts.sleep_time = atoi (optarg);
          break;

        case 'i':
          myopts.daemon = 0;
          break;

        case 'b':
          snprintf (myopts.snort_bin, sizeof (myopts.snort_bin), "%s",
                    optarg);
          break;

        case 'a':
          snprintf (myopts.snort_opts, sizeof (myopts.snort_opts), "%s",
                    optarg);
          break;

        case '?':
          ShowUsage ();
          exit (0);
          break;
        }
    }

  /*
   * Check if we have enuff information to do our job...
   */

  if (myopts.sid == 0)
    {
      printf ("Error: Sensor ID not specified!\n");
      err = 1;
    }

  if (!myopts.db_user[0])
    {
      printf ("Error: DB username not specified!\n");
      err = 1;
    }

  if (!myopts.db_port)
    {
      printf ("Error: DB port not specified!\n");
      err = 1;
    }

  if (!myopts.db_pass[0])
    {
      printf
        ("Warning: DB password not specified - assuming empty password\n");
    }

  if (!myopts.db_name[0])
    {
      printf ("Error: DB name not specified!\n");
      err = 1;
    }

  if (!myopts.db_host[0])
    {
      printf ("Error: DB host not specified!\n");
      err = 1;
    }

  print_config ();

  if (err)
    {
      printf ("\nFor usage help, enter \"extractrules\"\n\n");
      exit (0);
    }

  if (myopts.verbose >= 1)
    printf ("Checking for sensor %d\n", myopts.sid);

  /*
   * If the user want to go in daemon mode, make sure that sleep time
   * has been specified.. If not assume 60 seconds of sleep time
   */

  if (myopts.daemon == 1 && myopts.sleep_time == 0)
    {
      if (myopts.verbose >= 1)
        printf ("Warning: Daemon mode specified, but sleep time is 0 "
                "- setting default sleep time of %d seconds\n",
                DEFAULT_SLEEP_TIME);
      myopts.sleep_time = DEFAULT_SLEEP_TIME;
    }




  /*
   * Open the connection to the database server
   */

  if (!(mysql = mysql_init (NULL)))
    {
      fprintf (stderr, "Insufficient memory to allocate MYSQL object!\n");
      exit (1);
    }

  mysql_options (mysql, MYSQL_OPT_COMPRESS, 0);
  /*mysql_options (mysql, MYSQL_READ_DEFAULT_GROUP, "sguil_deploy_rules"); */

  if (!mysql_real_connect
      (mysql, myopts.db_host, myopts.db_user, myopts.db_pass, myopts.db_name,
       myopts.db_port, NULL, CLIENT_COMPRESS))
    {
      fprintf (stderr, "Failed to connect to database: Error: %s\n",
               mysql_error (mysql));
    }
  else
    {

      /*
       * Run the queries etc...
       */

      while (1)
        {
          /* Is the DB still alive? */
          while (mysql_ping (mysql))
            {
              if (myopts.verbose)
                printf
                  ("Connection to MySQL database lost. Waiting 5 seconds...\n");

              sleep (5);

            }

          if (updated (myopts.sid))
            {
              if (myopts.verbose >= 1)
                printf ("New signatures are available\n");

              if (myopts.verbose >= 1)
                printf ("Getting the variables\n");

              outputvars (myopts.sid);

              if (myopts.verbose >= 1)
                printf ("Getting the rules\n");

              outputrules (myopts.sid);

              if (myopts.verbose >= 1)
                printf ("Getting the BPF filter\n");

              outputfilter (myopts.sid);

              if (myopts.verbose >= 1)
                printf ("Testing the configuration\n");

              if (config_test () != 0)
                {
                  fprintf (stderr, "Error with the new configuration\n");
                }
              else
                {
                  run_command_after_updating ();
                }

            }

          if (myopts.daemon == 1)
            {
              /* Wait some time before we do the loop again... */
              if (myopts.verbose >= 1)
                printf ("Sleeping for %d seconds\n", myopts.sleep_time);

              sleep (myopts.sleep_time);
            }
          else
            {
              break;
            }

        }
      /*
       * Close the connection
       */

      mysql_close (mysql);

    }
}
