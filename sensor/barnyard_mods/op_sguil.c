/* $Id: op_sguil.c,v 1.9 2004/01/09 19:37:31 bamm Exp $ */
/*
** Copyright (C) 2001-2002 Andrew R. Baker <andrewb@snort.org>
**
** This program is distributed under the terms of version 1.0 of the 
** Q Public License.  See LICENSE.QPL for further details.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
**
*/

/* op_sguil is a modified op_acid_db plugin configured to work with
 * sguil (Snort GUI for Lamerz). Sguil and ACIDs DB schemas differ.
 * Sguil combines the event and iphdr tables along with moving the
 * src and dst port columns into event. I've also added SguilSendEvent
 * which opens a network socket and sends RT events to sguild.
 *
 * Andrew, sorry about mangling your code but it works so well :)
 *
 * Bammkkkk
*/

/*  I N C L U D E S  *****************************************************/


#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <time.h>
#include <errno.h>
#include <unistd.h>

#include "strlcpyu.h"
#include "configparse.h"
#include "plugbase.h"
#include "mstring.h"
#include "sid.h"
#include "classification.h"
#include "util.h"
#include "input-plugins/dp_log.h"
#include "op_plugbase.h"
#include "op_decode.h"
#include "event.h"

/* Needed for network socket */
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#ifdef ENABLE_MYSQL
#include <mysql.h>
#include <errmsg.h>
#endif /* ENABLE_MYSQL */

#ifdef ENABLE_POSTGRES

#endif /* ENABLE_POSTGRES */

/*  D A T A   S T R U C T U R E S  **************************************/
typedef struct _SguilOpData 
{
    u_int8_t flavor;  /* what flavor of db?  MySQL, postgres, ... */
    u_int16_t unused;
    char *server;
    char *database;
    char *user;
    char *password;
    int sensor_id;
    int options;
    char *sguild_host;
    int sguild_sock;
    int sguild_port;
    int nospin;
    u_int32_t event_id;
    /* db handles go here */
#ifdef ENABLE_MYSQL
    MYSQL *mysql;
#endif /* ENABLE_MYSQL */
#ifdef ENABLE_POSTGRES

#endif /* ENABLE_POSTGRES */
} SguilOpData;


#define MAX_QUERY_SIZE 8192
#define SYSLOG_BUF 1024

/* database flavor defines */
#define FLAVOR_MYSQL    1
#define FLAVOR_POSTGRES 2

char *sgdb_flavours[] = {NULL, "mysql", "postgres"};

/* Network socket defines */
#define MAX_MSG_LEN 100


/*  P R O T O T Y P E S  ************************************************/
int SguildConnect(SguilOpData *);
int SguilSendEvent(SguilOpData *data, char *eventMsg);
int read_line();
int SguilOpSetup(OutputPlugin *, char *args);
int SguilOpExit(OutputPlugin *);
int SguilOpStart(OutputPlugin *, void *);
int SguilOpStop(OutputPlugin *);
int SguilOpLog(void *, void *);

SguilOpData *SguilOpParseArgs(char *);
int sgDbClose(SguilOpData *data);
int sgDbConnect(SguilOpData *data);
u_int32_t SguilGetNextCid(SguilOpData *data);
u_int32_t SguilGetSensorId(SguilOpData *data);
int SguilCheckSchemaVersion(SguilOpData *data);
int InsertIPData(SguilOpData *data, Packet *p);
int sgInsertICMPData(SguilOpData *data, Packet *p);
int sgInsertUDPData(SguilOpData *data, Packet *p);
int sgInsertTCPData(SguilOpData *data, Packet *p);
int sgInsertPayloadData(SguilOpData *data, Packet *p);

int sgSelectAsUInt(SguilOpData *data, char *sql, unsigned int *result);
int sgInsert(SguilOpData *data, char *sql, unsigned int *row_id);
int sgBeginTransaction(SguilOpData *);
int sgEndTransaction(SguilOpData *);
int sgAbortTransaction(SguilOpData *);

#ifdef ENABLE_MYSQL
int sgMysqlConnect(SguilOpData *);
int sgMysqlClose(MYSQL *mysql);
int sgMysqlSelectAsUInt(MYSQL *mysql, char *sql, unsigned int *result);
int sgMysqlInsert(MYSQL *mysql, char *sql, unsigned int *row_id);
#endif

#ifdef ENABLE_POSTGRES
int PostgresConnect( );
int PostgresClose( );
int PostgresSelectAsUInt(  , char *sql, unsigned int *result);
int PostgresInsert(  , char *sql, unsigned int *row_id);
#endif /* ENABLE_POSTGRES */

/* Global variables */
static char sql_buffer[MAX_QUERY_SIZE];

/* 
 * Rather than using an incremental connection id (cid), this uses the
 * current time in milliseconds. BY is fast, but will we get dups in the
 * same millisecond?
 * Okay, lets wait on doing this.
long GetMilliseconds() 
{
    struct timeval  tv;
    gettimeofday(&tv, NULL);

    return (long)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}*/

/* init routine makes this processor available for dataprocessor directives */
void SguilOpInit()
{
    OutputPlugin *outputPlugin;
    PluginInfo pi;

    /* 
     * set the plugin info so you can get credit for your work, barnyard
     * is really self-documenting code... 
     */
    pi.author      = strdup("Andrew R. Baker");
    pi.version     = strdup("0.1");
    pi.type        = strdup("alert/log");
    pi.copyright   = strdup(
            "Copyright 2001 Andrew R. Baker <andrewb@snort.org>");
    pi.description = strdup("output plugin to populate the ACID database");
    pi.usage       = strdup("alert_acid_db: ?????");

    outputPlugin = RegisterOutputPlugin("sguil", "log", &pi);
    outputPlugin->setupFunc = SguilOpSetup;
    outputPlugin->exitFunc = SguilOpExit;
    outputPlugin->startFunc = SguilOpStart;
    outputPlugin->stopFunc = SguilOpStop;
    outputPlugin->outputFunc = SguilOpLog;
    
    /* free the plugin data */
    free(pi.author);
    free(pi.version);
    free(pi.type);
    free(pi.copyright);
    free(pi.description);
    free(pi.usage);

    /* tell people you're installed */
    LogMessage("Sguil output plugin initialized\n");
}


/* Setup the output plugin, process any arguments, link the functions to
 * the output functional node
 */
int SguilOpSetup(OutputPlugin *outputPlugin, char *args)
{
    /* setup the run time context for this output plugin */
    outputPlugin->data = SguilOpParseArgs(args);

    return 0;
}

/* Inverse of the setup function, free memory allocated in Setup 
 * can't free the outputPlugin since it is also the list node itself
 */
int SguilOpExit(OutputPlugin *outputPlugin)
{
    return 0;
}

/* 
 * this function gets called at start time, you should open any output files
 * or establish DB connections, etc, here
 */
int SguilOpStart(OutputPlugin *outputPlugin, void *spool_header)
{
    char tmpMsg [256];
    SguilOpData *data = (SguilOpData *)outputPlugin->data;
    LogMessage("SguilOpStart\n");

    if(data == NULL)
        FatalError("ERROR: Unable to find context for Sguil startup!\n");

    /* Connect to sguild */
    if(SguildConnect(data))
      FatalError("SguilOp: Failed to connect to sguild: %s:%i\n",
        data->sguild_host, data->sguild_port);

    /* Write a system-info message*/
    sprintf(tmpMsg, "RTEvent |||system-info|%s||Barnyard started.||||||||\n", pv.hostname);
    SguilSendEvent(data, tmpMsg);
    
    /* Connect to the database */
    if(sgDbConnect(data))
        FatalError("SguilOp: Failed to connect to database: %s:%s@%s/%s\n",
                data->user, data->password, data->server, data->database);

    /* check the db schema */
    /*if(SguilCheckSchemaVersion(data))
        FatalError("SguilOp: database schema mismatch\n");*/
 
    /* if sensor id == 0, then we attempt attempt to determine it dynamically */
    if(data->sensor_id == 0)
    {
        data->sensor_id = SguilGetSensorId(data);
        /* XXX: Error checking */
    }
    /* Get the next cid from the database */
    data->event_id = SguilGetNextCid(data);
    LogMessage("OpAcidDB configuration details\n");
    LogMessage("Database Flavour: %s\n", sgdb_flavours[data->flavor]);
    LogMessage("Database Server: %s\n", data->server);
    LogMessage("Database User: %s\n", data->user);
    LogMessage("SensorID: %i\n", data->sensor_id);
    LogMessage("Sguild Host: %s\n", data->sguild_host);
    LogMessage("Sguild Port: %i\n", data->sguild_port);
    if((data->nospin) == NULL)
    {
            LogMessage("Barnyard will sleep(15) if unable to connect to sguild.\n");
            data->nospin = 0;
    }
    else
    {
            LogMessage("Spinning disabled.\n");
    }
    LogMessage("SguilOpStart Complete\n"); fflush(stdout);

    sprintf(tmpMsg, "RTEvent |||system-info|%s||Database Server: %s.||||||||\n",
		   pv.hostname, data->server);
    SguilSendEvent(data, tmpMsg);

    sprintf(tmpMsg, "RTEvent |||system-info|%s||Database Next CID: %i.||||||||\n",
		    pv.hostname, data->event_id);
    SguilSendEvent(data, tmpMsg);
    return 0;
}

int SguilOpStop(OutputPlugin *outputPlugin)
{
    SguilOpData *data = (SguilOpData *)outputPlugin->data;

    LogMessage("SguilOpStop\n"); fflush(stdout);
    if(data == NULL)
        FatalError("ERROR: Unable to find context for Sguil startup!\n");

    /* close database connection */
    sgDbClose(data);
    
    return 0;
}

/* sguil only uses log */
int SguilOpLog(void *context, void *data)
{
    char timestamp[TIMEBUF_SIZE];
    char syslogMessage[SYSLOG_BUF];
    char eventInfo[SYSLOG_BUF];
    //int MAX_INSERT_LEN = 1024;
    char insertColumns[MAX_QUERY_SIZE];
    char insertValues[MAX_QUERY_SIZE];
    char valuesTemp[MAX_QUERY_SIZE];
    char ipInfo[38];
    char portInfo[16];
    char *esc_message;
    Sid *sid = NULL;
    ClassType *class_type;
    UnifiedLogRecord *record = (UnifiedLogRecord *)data; 
    SguilOpData *op_data = (SguilOpData *)context;
    Packet p;

    bzero(syslogMessage, SYSLOG_BUF);
    bzero(insertColumns, MAX_QUERY_SIZE);
    bzero(insertValues, MAX_QUERY_SIZE);

#if 0 /* this is broken */
    /* skip tagged packets, since the db does not have a mechanism to 
     * deal with them properly
     */
    if(record->log.event.event_reference)
    {
        LogMessage("Skipping tagged packet %i\n", record->log.event.event_reference);
        return 0;
    }
#endif
    

    RenderTimestamp(record->log.pkth.ts.tv_sec, timestamp, TIMEBUF_SIZE);
    //fprintf(stdout, "Timestamp: %lu\n", GetMilliseconds());
    //fflush(stdout);
    sid = GetSid(record->log.event.sig_generator, record->log.event.sig_id);
    if(sid == NULL)
        sid = FakeSid(record->log.event.sig_generator, record->log.event.sig_id);
    class_type = GetClassType(record->log.event.classification);

    //sgBeginTransaction(op_data); /* XXX: Error checking */
    /* Build the event insert. */
    snprintf(insertColumns, MAX_QUERY_SIZE,
      "INSERT INTO event (status, sid, cid, signature_id, signature_rev, signature, timestamp, priority, class");

    esc_message = malloc(strlen(sid->msg)*2+1);
    mysql_real_escape_string(op_data->mysql, esc_message, sid->msg, strlen(sid->msg));

    if(class_type == NULL)
    {
      snprintf(valuesTemp, MAX_QUERY_SIZE,
        "VALUES ('0', '%u', '%u', '%d', '%d', '%s', '%s', '%u', 'unknown'",
          op_data->sensor_id, op_data->event_id, sid->sid, sid->rev, esc_message, timestamp, 
	  record->log.event.priority);
    snprintf(eventInfo, SYSLOG_BUF, "RTEvent |0|%u|unknown|%s|%s|%u|%u|%s",
	    record->log.event.priority, 
	    pv.hostname, timestamp, op_data->sensor_id, op_data->event_id,
	    sid->msg);
    }
    else
    {
      snprintf(valuesTemp, MAX_QUERY_SIZE,
        "VALUES ('0', '%u', '%u', '%d', '%d', '%s', '%s', '%u', '%s'",
          op_data->sensor_id, op_data->event_id, sid->sid, sid->rev, esc_message, timestamp, 
	  record->log.event.priority, class_type->type);
      snprintf(eventInfo, SYSLOG_BUF, "RTEvent |0|%u|%s|%s|%s|%u|%u|%s",
	    record->log.event.priority, class_type->type,
	    pv.hostname, timestamp, op_data->sensor_id, op_data->event_id,
	    sid->msg);
    }

   free(esc_message);

	insertValues[0] = '\0';
	strcat(insertValues, valuesTemp);

    syslogMessage[0] = '\0';
    strcat(syslogMessage, eventInfo);
    /* decode the packet */
    DecodeEthPkt(&p, &record->log.pkth, record->pkt + 2);

    if(p.iph)
    {
        /* Insert ip header information */
        //InsertIPData(op_data, &p);
	strcat(insertColumns,
          ",src_ip, dst_ip, ip_proto, ip_ver, ip_hlen, ip_tos, ip_len, ip_id, ip_flags, ip_off, ip_ttl, ip_csum");
	snprintf(valuesTemp, MAX_QUERY_SIZE,
	  ",'%u', '%u', '%u', '%u', '%u', '%u', '%u', '%u', '%u', '%u', '%u', '%u'",
	   ntohl(p.iph->ip_src.s_addr), ntohl(p.iph->ip_dst.s_addr), p.iph->ip_proto, IP_VER(p.iph),
	  IP_HLEN(p.iph), p.iph->ip_tos, ntohs(p.iph->ip_len), ntohs(p.iph->ip_id),
#if defined(WORDS_BIGENDIAN)
          ((p.iph->ip_off & 0xE000) >> 13),
          htons(p.iph->ip_off & 0x1FFF),
#else
          ((p.iph->ip_off & 0x00E0) >> 5),
          htons(p.iph->ip_off & 0xFF1F),
#endif
          p.iph->ip_ttl,
          htons(p.iph->ip_csum) < MAX_QUERY_SIZE);

	strcat(insertValues, valuesTemp);


	/* SYSLOG - Changed to SguilSendEvent*/
	snprintf(ipInfo, 38, "|%u.%u.%u.%u|%u.%u.%u.%u|%u",
#if defined(WORDS_BIGENDIAN)
	    (p.iph->ip_src.s_addr & 0xff000000) >> 24,
	    (p.iph->ip_src.s_addr & 0x00ff0000) >> 16,
	    (p.iph->ip_src.s_addr & 0x0000ff00) >> 8,
	    (p.iph->ip_src.s_addr & 0x000000ff),
	    (p.iph->ip_dst.s_addr & 0xff000000) >> 24,
	    (p.iph->ip_dst.s_addr & 0x00ff0000) >> 16,
	    (p.iph->ip_dst.s_addr & 0x0000ff00) >> 8,
	    (p.iph->ip_dst.s_addr & 0x000000ff),
#else
	    (p.iph->ip_src.s_addr & 0x000000ff),
	    (p.iph->ip_src.s_addr & 0x0000ff00) >> 8,
	    (p.iph->ip_src.s_addr & 0x00ff0000) >> 16,
	    (p.iph->ip_src.s_addr & 0xff000000) >> 24,
	    (p.iph->ip_dst.s_addr & 0x000000ff),
	    (p.iph->ip_dst.s_addr & 0x0000ff00) >> 8,
	    (p.iph->ip_dst.s_addr & 0x00ff0000) >> 16,
	    (p.iph->ip_dst.s_addr & 0xff000000) >> 24,
#endif
	    p.iph->ip_proto);
	strcat(syslogMessage, ipInfo);

        /* store layer 4 data for non fragmented packets */
        if(!(p.pkt_flags & PKT_FRAG_FLAG))
        {
            switch(p.iph->ip_proto)
            {
                case IPPROTO_ICMP:
		    snprintf(portInfo, 16, "|||");
                    if(!p.icmph) 
			break;
       	            strcat(insertColumns,
		    ", icmp_type, icmp_code)");
		    snprintf(valuesTemp, MAX_QUERY_SIZE,
		    ", '%u', '%u')", p.icmph->icmp_type,
                    p.icmph->icmp_code);
		    strcat(insertValues, valuesTemp);
	            strcat(insertColumns, insertValues);
                    sgInsert(op_data, insertColumns, NULL);
                    sgInsertICMPData(op_data, &p);
                    break;
                case IPPROTO_TCP:
	            strcat(insertColumns,
		    ", src_port, dst_port)");
		    snprintf(valuesTemp, MAX_QUERY_SIZE,
		    ", '%u', '%u')", p.sp, p.dp);
		    strcat(insertValues, valuesTemp);
	            strcat(insertColumns, insertValues);
                    sgInsert(op_data, insertColumns, NULL);
                    sgInsertTCPData(op_data, &p);
		    snprintf(portInfo, 16, "|%u|%u|",
			p.sp, p.dp);
                    break;
                case IPPROTO_UDP:
	            strcat(insertColumns,
		    ", src_port, dst_port)");
		    snprintf(valuesTemp, MAX_QUERY_SIZE,
		    ", '%u', '%u')", p.sp, p.dp);
		    strcat(insertValues, valuesTemp);
	            strcat(insertColumns, insertValues);
                    sgInsert(op_data, insertColumns, NULL);
                    sgInsertUDPData(op_data, &p);
		    snprintf(portInfo, 16, "|%u|%u|",
			p.sp, p.dp);
                    break;
            }
	    strcat(syslogMessage, portInfo);
        }
	else
	{
		strcat(syslogMessage, "|||");
	}


		/* Insert payload data */
	        sgInsertPayloadData(op_data, &p);
	    }
            else
            {
		strcat(syslogMessage, "||||||");
             }

	    //sgEndTransaction(op_data);  /* XXX: Error Checking */
	    ++op_data->event_id;
            /* Append the sig id and rev to the RT event */
            snprintf(eventInfo, SYSLOG_BUF, "%u|%u|\n", sid->sid, sid->rev);
            strcat(syslogMessage, eventInfo);
	    /* Write to the network socket */
	    SguilSendEvent(op_data, syslogMessage);
	    return 0;
	}

int sgInsertUDPData(SguilOpData *op_data, Packet *p)
{
    if(!p->udph)
        return 0;
        if(snprintf(sql_buffer, MAX_QUERY_SIZE,
                "INSERT INTO udphdr(sid, cid, udp_len, udp_csum)"
	        "VALUES ('%u', '%u', '%u', '%u')", 
                op_data->sensor_id, op_data->event_id,
                ntohs(p->udph->uh_len), 
                ntohs(p->udph->uh_chk)) < MAX_QUERY_SIZE)
        {
            sgInsert(op_data, sql_buffer, NULL);  /* XXX: Error Checking */
        }
    return 0;
}

int sgInsertTCPData(SguilOpData *op_data, Packet *p)
{
    if(!p->tcph)
        return 0;

    /* insert data into the tcp header table */
        if(snprintf(sql_buffer, MAX_QUERY_SIZE,
                "INSERT INTO tcphdr(sid, cid, tcp_seq, "
                "tcp_ack, tcp_off, tcp_res, tcp_flags, tcp_win, tcp_csum, "
                "tcp_urp) VALUES('%u', '%u', '%u', '%u', '%u', "
                "'%u', '%u', '%u', '%u', '%u')",
                op_data->sensor_id, op_data->event_id,
                ntohl(p->tcph->th_seq), ntohl(p->tcph->th_ack),
                TCP_OFFSET(p->tcph), TCP_X2(p->tcph), p->tcph->th_flags,
                ntohs(p->tcph->th_win), ntohs(p->tcph->th_sum),
                ntohs(p->tcph->th_urp)) < MAX_QUERY_SIZE)
        {
            sgInsert(op_data, sql_buffer, NULL);  /* XXX: Error checking */
        }
        /* XXX: TCP Options not handled */
    return 0;
}

int sgInsertICMPData(SguilOpData *op_data, Packet *p)
{
    if(!p->icmph)
        return 0;
        if(p->icmph->icmp_type == 0 || p->icmph->icmp_type == 8 ||
                p->icmph->icmp_type == 13 || p->icmph->icmp_type == 14 ||
                p->icmph->icmp_type == 15 || p->icmph->icmp_type == 16)
        {
            if(snprintf(sql_buffer, MAX_QUERY_SIZE,
                    "INSERT INTO icmphdr(sid, cid, "
                    "icmp_csum, icmp_id, icmp_seq) "
                    "VALUES('%u', '%u', '%u', '%u', '%u')", 
                    op_data->sensor_id, op_data->event_id, 
                    ntohs(p->icmph->icmp_csum),
                    htons(p->icmph->icmp_hun.ih_idseq.icd_id),
                    htons(p->icmph->icmp_hun.ih_idseq.icd_seq)) 
                    < MAX_QUERY_SIZE)
            {
                sgInsert(op_data, sql_buffer, NULL);  /* XXX: Error checking */
            }
        }
        else
        {
            if(snprintf(sql_buffer, MAX_QUERY_SIZE,
                    "INSERT INTO icmphdr(sid, cid, "
                    "icmp_csum) VALUES('%u', '%u', '%u')", 
                    op_data->sensor_id, op_data->event_id,
                    ntohs(p->icmph->icmp_csum))
                    < MAX_QUERY_SIZE)
            {
                sgInsert(op_data, sql_buffer, NULL);  /* XXX: Error Checking */
            }
        }
    return 0;
}

int sgInsertPayloadData(SguilOpData *op_data, Packet *p)
{
    char *hex_payload;
    if(p->dsize)
    {
        hex_payload = fasthex(p->data, p->dsize);
        if(snprintf(sql_buffer, MAX_QUERY_SIZE,
                "INSERT INTO data(sid, cid, data_payload) "
                "VALUES('%u', '%u', '%s')", op_data->sensor_id, 
                op_data->event_id, hex_payload) < MAX_QUERY_SIZE)
        {
            sgInsert(op_data, sql_buffer, NULL);  /* XXX: Error Checking */
        }
        free(hex_payload);
    }
    return 0;
}


/* Attempts to retrieve the sensor id
 */
unsigned int SguilGetSensorId(SguilOpData *op_data)
{
    unsigned int sensor_id = 0;
    /* XXX:  This should be moved to global setup */
    if(pv.hostname == NULL)
    {
        /* query the hostname */
        /* the DB schema allows for a hostname of up to 2^16-1 characters, i am limiting
         * this to 255 (+1 for the NULL)
         */
        pv.hostname = (char *)malloc(256);
        if(gethostname(pv.hostname, 256))
        {
            FatalError("Error querying hostname: %s\n", strerror(errno));
        }
    }

    /* XXX: need to escape strings */
    if(snprintf(sql_buffer, MAX_QUERY_SIZE, 
                "SELECT sid FROM sensor WHERE hostname='%s'"
                , pv.hostname) < MAX_QUERY_SIZE)
    {
        if(sgSelectAsUInt(op_data, sql_buffer, &sensor_id) == -1)
        {
            FatalError("Database Error\n");
        }
        if(sensor_id == 0)
        {

            /* insert sensor information */

            if(snprintf(sql_buffer, MAX_QUERY_SIZE, "INSERT INTO sensor (hostname) "
                        "VALUES ('%s')", pv.hostname) < MAX_QUERY_SIZE)
            {
                sgInsert(op_data, sql_buffer, &sensor_id); 
                /* XXX: Error checking */
            }
            else
            {
                FatalError("Error building SQL Query\n");
            }
        }
        LogMessage("sensor_id == %u\n", sensor_id);
    }
    else
    {
        FatalError("Error building SQL Query\n");
    } 
    return sensor_id;
}

/* Retrieves the next acid_cid to use for inserting into the database for this
 * sensor
 */
unsigned int SguilGetNextCid(SguilOpData *data)
{
    unsigned int cid = 0;
    if(snprintf(sql_buffer, MAX_QUERY_SIZE, 
                "SELECT max(cid) FROM event WHERE sid='%u'", data->sensor_id) 
            < MAX_QUERY_SIZE)
    {
        if(sgSelectAsUInt(data, sql_buffer, &cid) == -1)
        {
            FatalError("Database Error\n");
        }
#ifdef DEBUG
        LogMessage("cid == %u\n", cid); fflush(stdout);
#endif
    }
    else
    {
        FatalError("Database Error\n");
    } 
    return ++cid;
}

SguilOpData *SguilOpParseArgs(char *args)
{
    SguilOpData *op_data;

    op_data = (SguilOpData *)SafeAlloc(sizeof(SguilOpData));

    op_data->options = 0;

    if(args != NULL)
    {
        char **toks;
        int num_toks;
        int i;
        /* parse out your args */
        LogMessage("Args: %s\n", args);
        toks = mSplit(args, ",", 31, &num_toks, '\\');
        for(i = 0; i < num_toks; ++i)
        {
            char **stoks;
            int num_stoks;
            char *index = toks[i];
            while(isspace((int)*index))
                ++index;
            stoks = mSplit(index, " ", 2, &num_stoks, 0);
            if(strcasecmp("database", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->database == NULL)
                    op_data->database = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
            else if(strcasecmp("server", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->server == NULL)
                    op_data->server = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
            else if(strcasecmp("user", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->user == NULL)
                    op_data->user = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
            else if(strcasecmp("password", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->password == NULL)
                    op_data->password = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
            else if(strcasecmp("sensor_id", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->sensor_id == 0)
                    op_data->sensor_id = atoi(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
	    else if(strcasecmp("sguild_host", stoks[0]) == 0)
	    {
		if(num_stoks > 1 && op_data->sguild_host == 0)
		    op_data->sguild_host = strdup(stoks[1]);
	        else
	            LogMessage("Argument Error in %s(%i): %s\n", file_name,
			    file_line, index);
	    }
            else if(strcasecmp("nospin", stoks[0]) == 0)
            {
                    op_data->nospin = 1;
            }
	    else if(strcasecmp("sguild_port", stoks[0]) == 0)
            {
		if(num_stoks > 1 && op_data->sguild_port == 0)
		    op_data->sguild_port = atoi(stoks[1]);
	        else
	            LogMessage("Argument Error in %s(%i): %s\n", file_name,
			    file_line, index);
	    }

#ifdef ENABLE_MYSQL
            else if(strcasecmp("mysql", stoks[0]) == 0)
            {   
                if(op_data->flavor == 0)
                    op_data->flavor = FLAVOR_MYSQL;
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name, 
                            file_line, index);
            }
#endif /* ENABLE_MYSQL */
#ifdef ENABLE_POSTGRES
            else if(strcasecmp("postgres", stoks[0]) == 0)
            {
                if(op_data->flavor == 0)
                    op_data->flavor = FLAVOR_POSTGRES;
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name,
                            file_line, index);
            }
#endif /* ENABLE_POSTGRES */
            else
            {
                fprintf(stderr, "WARNING %s (%d) => Unrecognized argument for "
                        "Sguil plugin: %s\n", file_name, file_line, index);
            }
            FreeToks(stoks, num_stoks);
        }
        /* free your mSplit tokens */
        FreeToks(toks, num_toks);
    }
    if(op_data->flavor == 0)
    FatalError("You must specify a database flavor\n");

    if (op_data->sguild_host == NULL)
    {
	FatalError("You must specify a sguild host.\n");
    }

    if (!op_data->sguild_port)
    {
	FatalError("You must specify a sguild port.\n");
    }
    return op_data;
}


int sgDbConnect(SguilOpData *op_data)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlConnect(op_data);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresConnect(op_data);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
//    return 1;
}

int sgDbClose(SguilOpData *op_data)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:  
            return sgMysqlClose(op_data->mysql);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresClose(op_data->pq);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}


int sgSelectAsUInt(SguilOpData *op_data, char *sql, unsigned int *result)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlSelectAsUInt(op_data->mysql, sql, result);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresSelectAsUInt(op_data->pq, sql, result);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}

int sgInsert(SguilOpData *op_data, char *sql, unsigned int *row_id)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlInsert(op_data->mysql, sql, row_id);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresInsert(op_data->pq, sql, result);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}

int sgBeginTransaction(SguilOpData *op_data)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlInsert(op_data->mysql, "BEGIN", NULL);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresInsert(op_data->pq, "BEGIN", NULL);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}

int sgEndTransaction(SguilOpData *op_data)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlInsert(op_data->mysql, "COMMIT", NULL);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresInsert(op_data->pq, "COMMIT", NULL);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}
    
int sgAbortTransaction(SguilOpData *op_data)
{
    switch(op_data->flavor)
    {
#ifdef ENABLE_MYSQL
        case FLAVOR_MYSQL:
            return sgMysqlInsert(op_data->mysql, "ROLLBACK", NULL);
#endif
#ifdef ENABLE_POSTGRES
        case FLAVOR_POSTGRES:
            return PostgresInsert(op_data->pq, "ROLLBACK", NULL);
#endif /* ENABLE_POSTGRES */
        default:
            FatalError("Database flavor not supported\n");
            return 1;
    }
}


#ifdef ENABLE_MYSQL
int sgMysqlConnect(SguilOpData *op_data)
{
    op_data->mysql = mysql_init(NULL);
    if(!mysql_real_connect(op_data->mysql, op_data->server, op_data->user, 
                op_data->password, op_data->database, 0, NULL, 0))
    {
        FatalError("Failed to connect to database %s:%s@%s/%s: %s\n",
                op_data->user, op_data->password, op_data->server, 
                op_data->database, mysql_error(op_data->mysql));
    }
    return 0;
}

int sgMysqlClose(MYSQL *mysql)
{
    mysql_close(mysql);
    return 0;
}

int sgMysqlExecuteQuery(MYSQL *mysql, char *sql)
{
    int mysqlErrno;
    int result;
    while((result = mysql_query(mysql, sql) != 0))
    {
        mysqlErrno = mysql_errno(mysql);
        if(mysqlErrno < CR_MIN_ERROR)
        {
            if(pv.verbose)
                LogMessage("MySQL ERROR(%i): %s.  Aborting Query\n",
                        mysql_errno(mysql), mysql_error(mysql));
            return result;
        }
        if((mysqlErrno == CR_SERVER_LOST) 
                || (mysqlErrno == CR_SERVER_GONE_ERROR))
        {
            LogMessage("Lost connection to MySQL server.  Reconnecting\n");
            while(mysql_ping(mysql) != 0)
            {
                if(BarnyardSleep(15))
                    return result;
            }
            LogMessage("Reconnected to MySQL server.\n");
        }
        else
        {
            /* XXX we could spin here, but we do not */
            LogMessage("MySQL Error(%i): %s\n", mysqlErrno, mysql_error(mysql));
        }
    }
    return result;
}


int sgMysqlSelectAsUInt(MYSQL *mysql, char *sql, unsigned int *result)
{
    int rval = 0;
    MYSQL_RES *mysql_res;
    MYSQL_ROW tuple;
    
    if(sgMysqlExecuteQuery(mysql, sql) != 0)
    {
        /* XXX: should really just return up the chain */
        FatalError("Error (%s) executing query: %s\n", mysql_error(mysql), sql);
        return -1;
    }

    mysql_res = mysql_store_result(mysql);
    if((tuple = mysql_fetch_row(mysql_res)))
    {
        if(tuple[0] == NULL)
            *result = 0;
        else
            *result = atoi(tuple[0]);
        rval = 1;
    }
    mysql_free_result(mysql_res);
    return rval;
}

int sgMysqlInsert(MYSQL *mysql, char *sql, unsigned int *row_id)
{
    if(sgMysqlExecuteQuery(mysql, sql) != 0)
    {
        /* XXX: should really just return up the chain */
        FatalError("Error (%s) executing query: %s\n", mysql_error(mysql), sql);
        return -1;
    }

    if(row_id != NULL)
        *row_id = mysql_insert_id(mysql);
    return 0;
}
#endif

#ifdef ENABLE_POSTGRES
int PostgresConnect(SguilOpData *op_data)
{

    return 0;
}

int PostgresClose( )
{
    
}

int PostgresSelectAsUInt( , char *sql, unsigned int *result)
{

    return 0;
}

int PostgresInsert(, char *sql, unsigned int *row_id)
{


    return 0;
}
#endif /* ENABLE_POSTGRES */


/* SguildConnect() opens a network socket to sguild for sending
 * RT event messages.  Bammkkkk
*/
int SguildConnect(SguilOpData *op_data)
{
	int sockfd;
	struct hostent *he;
	struct sockaddr_in server_addr;

	if ((he=gethostbyname(op_data->sguild_host)) == NULL)
        {
                FatalError("Cannot resolve hostname: %s\n", op_data->sguild_host);
                return 1;
        }
        
        if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
        {
 
            FatalError("Cannot open a local socket.\n");
            return 1;
 
        }

        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(op_data->sguild_port);
        server_addr.sin_addr = *((struct in_addr *)he->h_addr);
        memset(&(server_addr.sin_zero), '\0', 8);

        if (connect(sockfd, (struct sockaddr *)&server_addr, sizeof(struct sockaddr)) < 0)
        {
                                                                                                              
           LogMessage("Cannot connect to %s on TCP port %u.\n",
                op_data->sguild_host, op_data->sguild_port);
           close(sockfd);
           return 1;

        } 

        op_data->sguild_sock = sockfd;
        return 0;

}
/* I love google. http://pont.net/socket/prog/tcpServer.c */
int read_line(int newSd, char *line_to_return) {
  
  static int rcv_ptr=0;
  static char rcv_msg[MAX_MSG_LEN];
  static int n;
  int offset;

  offset=0;

  while(1) {
    if(rcv_ptr==0) {

      memset(rcv_msg,0x0,MAX_MSG_LEN);
      n = recv(newSd, rcv_msg, MAX_MSG_LEN, 0);
      if (n<0) {
	LogMessage("ERROR: Unable to read data.\n");
	return 1;
      } else if (n==0) {
	LogMessage("ERROR: Connecton closed by client\n");
	close(newSd);
	return 1;
      }
    }
  
    /* if new data read on socket */
    /* OR */
    /* if another line is still in buffer */

    /* copy line into 'line_to_return' */
    while(*(rcv_msg+rcv_ptr)!=0x0A && rcv_ptr<n) {
      memcpy(line_to_return+offset,rcv_msg+rcv_ptr,1);
      offset++;
      rcv_ptr++;
    }
    
    /* end of line + end of buffer => return line */
    if(rcv_ptr==n-1) { 
      /* set last byte to END_LINE */
      *(line_to_return+offset)=0x0A;
      rcv_ptr=0;
      return ++offset;
    } 
    
    /* end of line but still some data in buffer => return line */
    if(rcv_ptr <n-1) {
      /* set last byte to END_LINE */
      *(line_to_return+offset)=0x0A;
      rcv_ptr++;
      return ++offset;
    }

    /* end of buffer but line is not ended => */
    /*  wait for more data to arrive on socket */
    if(rcv_ptr == n) {
      rcv_ptr = 0;
    } 
    
  }
}

/* SguilSendEvent() sends the event via the open network socket.
 * Bammkkkk
*/
int SguilSendEvent(SguilOpData *op_data, char *eventMsg)
{

     int schars;
     char line[100];
     

     if((schars = send(op_data->sguild_sock, eventMsg, strlen(eventMsg), 0)) < 0)
     {
             LogMessage("ERROR! Couldn't send msg.\n");

             /* ReConnect to sguild */
             while(SguildConnect(op_data) == 1)
             {
                 if(op_data->nospin) return 0;
                 LogMessage("ERROR: Couldn't reconnect. Will try again in 15 secs.\n");
                 if (BarnyardSleep(15)) break;
             }
             LogMessage("Connected to %s.\n", op_data->sguild_host);
             SguilSendEvent(op_data, eventMsg);

     } else {

             //LogMessage("Msg sent: %s", eventMsg);
             //LogMessage("Chars sent: %i\n", schars);

             memset(line, 0x0, 100);
             if(read_line(op_data->sguild_sock, line) == 1)
             {

                 if (op_data->nospin == 0)
                 {


                    LogMessage("ERROR! Didn't receive confirmation. Trying to reconnect.\n");

                    /* ReConnect to sguild */
                    while(SguildConnect(op_data) == 1)
                    {
                        LogMessage("ERROR: Couldn't reconnect. Will try again in 15 secs.\n");
                        if (BarnyardSleep(15)) break;
                    }
 
                    LogMessage("Connected to %s.\n", op_data->sguild_host);
                    SguilSendEvent(op_data, eventMsg);

                 }

             }
     }
     return 0;
     
}
