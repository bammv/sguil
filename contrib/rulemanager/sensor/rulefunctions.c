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

extern char sql_query[SQL_QUERY_SIZE];
extern MYSQL *mysql;
extern MYSQL_RES *result;
extern MYSQL_ROW row;
extern FILE *filehandle;
extern int error;

extern struct sguil_rule_opts myopts;

int
run_command_after_updating (void)
{
  char scream[BUFFER_SIZE];

  openlog ("sguil_extractrules", LOG_PID | LOG_PERROR, LOG_USER);

  if (strlen (myopts.command) >= 0)
    {
      if (system (myopts.command) == -1)
        {
          snprintf (scream, sizeof (scream),
                    "Something went wrong when trying to execute '%s'",
                    myopts.command);
          syslog (LOG_ERR, "%s", scream);
        }
    }
  else
    {
      snprintf (scream, sizeof (scream),
                "Silly user, you didn't specify what you wanted to execute after updating the ruleset.");
      syslog (LOG_WARNING, "%s", scream);
    }

  closelog ();

}

int
config_test (void)
{
  /*
   * Tests the new configuration. If it works it will use the new files,
   * if not it will revert back to the old version.
   *
   * Returns 0 on success, != 0 on failure
   */

  char new_filename[BUFFER_SIZE];
  char old_filename[BUFFER_SIZE];
  char command[1024];
  int return_code;

  /* 
   * Did the user specify where snort lives and what arguments to use?
   * Just check if there is a command to run, else bail out
   */

  if (strlen (myopts.snort_bin) == 0)
    {
      if (myopts.verbose >= 1)
        printf ("No snort process to run, won't test the rules\n");
      return (0);
    }

  /* Rename the variables file */
  snprintf (old_filename, sizeof (old_filename), "%s.old",
            myopts.var_filename);
  snprintf (new_filename, sizeof (new_filename), "%s.new",
            myopts.var_filename);
  rename (myopts.var_filename, old_filename);
  rename (new_filename, myopts.var_filename);

  /* Rename the rules file */
  snprintf (old_filename, sizeof (old_filename), "%s.old",
            myopts.rule_filename);
  snprintf (new_filename, sizeof (new_filename), "%s.new",
            myopts.rule_filename);
  rename (myopts.rule_filename, old_filename);
  rename (new_filename, myopts.rule_filename);

  /* Run snort in test mode */
  snprintf (command, sizeof (command), "%s %s -T", myopts.snort_bin,
            myopts.snort_opts);

  if (myopts.verbose >= 2)
    printf ("command: %s\n", command);
  return_code = system (command);

  if (return_code != 0)
    {
      /* Rename the variables file */
      snprintf (old_filename, sizeof (old_filename), "%s.old",
                myopts.var_filename);
      snprintf (new_filename, sizeof (new_filename), "%s.new",
                myopts.var_filename);
      rename (myopts.var_filename, new_filename);
      rename (old_filename, myopts.var_filename);

      /* Rename the rules file */
      snprintf (old_filename, sizeof (old_filename), "%s.old",
                myopts.rule_filename);
      snprintf (new_filename, sizeof (new_filename), "%s.new",
                myopts.rule_filename);
      rename (myopts.rule_filename, new_filename);
      rename (old_filename, myopts.rule_filename);
    }

  return (return_code);
}

int
updated (int sid)
{
  /*
   * Checks if database rulesset has been updated since last poll.
   * Returns:
   *  0 if no update has occured
   *  1 (or greater) if there is updated data for the sensor
   */

  int updated = 0;              /* returns number of rows from SELECT query */
  struct tm *mytime;
  char timestring[BUFFER_SIZE];
  time_t epoch_time;

  timestring[0] = '\0';
  /* Open the file */

  if ((filehandle = fopen (myopts.timestamp_filename, "r")) != NULL)
    {
      fgets (timestring, sizeof (timestring), filehandle);
      fclose (filehandle);
    }

  /* Create the query */

  if (strlen (timestring) > 0)
    {
      snprintf (sql_query, sizeof (sql_query),
                "SELECT updated FROM sensor WHERE sid=%d  AND updated > %s",
                sid, timestring);
    }
  else
    {
      snprintf (sql_query, sizeof (sql_query),
                "SELECT updated FROM sensor WHERE sid=%d ", sid);
    }

  if (myopts.verbose >= 2)
    printf ("SQL Query: %s\n", sql_query);

  /* Send the query */
  if (mysql_query (mysql, sql_query))
    {
      printf ("Query: '%s' failed\nBailing out!\n", sql_query);
      exit (1);
    }

  /* return the result */
  result = mysql_use_result (mysql);

  if (result == NULL)
    fprintf (stderr, "%s\n", mysql_error (mysql));

  while (row = mysql_fetch_row (result))
    {
      updated++;
    }
  mysql_free_result (result);


  /* Let's update the timestamp file */
  if ((filehandle = fopen (myopts.timestamp_filename, "w")) != NULL)
    {
      epoch_time = time (NULL);
      mytime = gmtime (&epoch_time);
      strftime (timestring, sizeof (timestring), "%Y%m%d%H%M%S", mytime);
      fprintf (filehandle, "%s", timestring);
      fclose (filehandle);
    }

  if (myopts.verbose >= 2)
    printf ("Updated: %d\n", updated);

  return (updated);
}

int
outputvars (int sid)
{
  char new_filename[BUFFER_SIZE];

  snprintf (new_filename, sizeof (new_filename), "%s.new",
            myopts.var_filename);

  if ((filehandle = fopen (new_filename, "w")) != NULL)
    {

      snprintf (sql_query, sizeof (sql_query),
                "SELECT "
                "   DISTINCTROW(vname), "
                "   value, "
                "   sid "
                "FROM "
                "   rman_vars "
                "NATURAL JOIN rman_varvals "
                "WHERE "
                "   sid=%d OR "
                "   sid=0 " "ORDER BY " "   rman_vars.vid, " "   sid", sid);

      if (mysql_query (mysql, sql_query))
        {
          printf ("Query '%s' filed\nBailing out!\n", sql_query);
          exit (1);
        }
      result = mysql_use_result (mysql);


      while ((row = mysql_fetch_row (result)))
        {
          fprintf (filehandle, "var %s %s\n", row[0], row[1]);
          if (myopts.verbose >= 3)
            printf ("var %s %s\n", row[0], row[1]);
        }

      mysql_free_result (result);
      fclose (filehandle);
    }
}

int
outputrules (int sid)
{
  char new_filename[BUFFER_SIZE];

  FILE *sidmsg_filehandle;

  if (myopts.update_sidmap)
    {
      if ((sidmsg_filehandle = fopen (myopts.sidfile, "w")) == NULL)
        {
          if (myopts.verbose >= 1)
            printf
              ("Can't open %s for writing. sid-msg.map won't be updated.\n",
               myopts.sidfile);
          return (1);
        }
    }

  snprintf (new_filename, sizeof (new_filename), "%s.new",
            myopts.rule_filename);

  if ((filehandle = fopen (new_filename, "w")) != NULL)
    {
      snprintf (sql_query, sizeof (sql_query),
                "SELECT"
                "	rman_rules.action, "
                "	rman_rules.proto,  "
                "	rman_rules.s_ip,  "
                "	rman_rules.s_port,  "
                "	rman_rules.dir,  "
                "	rman_rules.d_ip,  "
                "	rman_rules.d_port, "
                "	rman_rules.options,  "
                "	rman_rules.rid, "
                "	rman_rules.name "
                "FROM  "
                "	rman_rules, "
                "	rman_rrgid, "
                "	rman_senrgrp "
                "WHERE  "
                "	rman_senrgrp.sid=%d AND "
                "	rman_senrgrp.rgid=rman_rrgid.rgid AND "
                "	rman_rrgid.rid=rman_rules.rid AND  "
                "	rman_rules.active='Y'", sid);

      error = mysql_query (mysql, sql_query);
      result = mysql_use_result (mysql);


      while ((row = mysql_fetch_row (result)))
        {
          fprintf (filehandle, "%s %s %s %s %s %s %s (%s)\n",
                   row[0], row[1], row[2], row[3], row[4], row[5], row[6],
                   row[7]);
          if (myopts.verbose >= 3)
            printf ("%s %s %s %s %s %s %s (%s)\n",
                    row[0], row[1], row[2], row[3], row[4], row[5], row[6],
                    row[7]);

          if (myopts.update_sidmap)
            {
              if (sidmsg_filehandle != NULL)
                {
                  fprintf (sidmsg_filehandle, "%d || %s\n", row[8], row[9]);
                }
            }

        }

      mysql_free_result (result);

      if (sidmsg_filehandle)
        fclose (sidmsg_filehandle);

      if (filehandle)
        fclose (filehandle);
    }

  return (0);
}

int outputfilter (int sid) {
  char new_filename[BUFFER_SIZE];

  FILE *filehandle;

  snprintf (new_filename, sizeof (new_filename), "%s/filter.bpf",
            myopts.config_dir);

  if ((filehandle = fopen (new_filename, "w")) != NULL)
    {
      snprintf (sql_query, sizeof (sql_query),
                "SELECT"
                "	sensor.bpf_filter "
                "FROM  "
                "	sensor "
                "WHERE  "
                "	sensor.sid=%d AND"
                "	sensor.active='Y'", sid);

      error = mysql_query (mysql, sql_query);
      result = mysql_use_result (mysql);

      while ((row = mysql_fetch_row (result)))
        {
          fprintf (filehandle, "%s\n", row[0]);
        }

      mysql_free_result (result);

      if (filehandle)
        fclose (filehandle);
    }

  return (0);
}
