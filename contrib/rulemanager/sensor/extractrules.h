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
 
#ifndef _EXTRACTRULES_H
#define _EXTRACTRULES_H 


#define SQL_QUERY_SIZE 8192
#define BUFFER_SIZE 1024
#define DEFAULT_SLEEP_TIME 60


char sql_query[SQL_QUERY_SIZE];
int error;
FILE *filehandle;

MYSQL *mysql;
MYSQL_RES *result;
MYSQL_ROW row;

struct sguil_rule_opts
{
  int verbose;
  int daemon;
  int update_sidmap;
  int update_filter;
  int sid;

  char timestamp_filename[BUFFER_SIZE];
  char var_filename[BUFFER_SIZE];
  char rule_filename[BUFFER_SIZE];
  char sidfile[BUFFER_SIZE];
  char config_dir[BUFFER_SIZE];

  char db_user[BUFFER_SIZE];
  char db_pass[BUFFER_SIZE];
  char db_name[BUFFER_SIZE];
  char db_host[BUFFER_SIZE];
  unsigned int db_port;

  char snort_bin[BUFFER_SIZE];
  char snort_opts[BUFFER_SIZE];

  char command[BUFFER_SIZE];
  int sleep_time;
};

#endif /* _EXTRACTRULES_H */
