/* $Id: spp_stream4.c,v 1.1 2003/04/30 22:08:02 bamm Exp $ */

/*
** Copyright (C) 1998-2002 Martin Roesch <roesch@sourcefire.com>
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/


/* spp_stream4 
 * 
 * Purpose: Stateful inspection and tcp stream reassembly in Snort
 *
 * Arguments:
 *   
 * Effect:
 *
 * Comments:
 *
 * Any comments?
 *
 */

/* Added a new stats type "db". The main purpose is to get session stats loaded
 * into the database for datamining using sguil (http://www.satexas.com/~bamf/sguil/).
 * 
 * Config from snort.conf:
 * keepstats db /log/dir
 *
 *
 * Output is pipe deliminated and a new file (/log/dir/ssn_log.<milliseconds>)
 * is created each time the deleted sessions are flushed (see FLUSH_DELAY):
 *
 * xid|start_time|end_time|src_ip|dst_ip|src_port|dst_port|src_pckts|dst_pckts|src_bytes|dst_bytes
 *
 * xid is the time in milliseconds at SessionDelete.
 *
 *
 * Bammkkkk
*/

/*  I N C L U D E S  ************************************************/
#include <sys/types.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#ifndef WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif /* WIN32 */
#include <time.h>
#include <rpc/types.h>
#include <unistd.h>

#include "decode.h"
#include "event.h"
#include "debug.h"
#include "util.h"
#include "plugbase.h"
#include "parser.h"
#include "mstring.h"
#include "checksum.h"
#include "log.h"
#include "generators.h"
#include "detect.h"
#include "perf.h"

#include "ubi_SplayTree.h"

#include "snort.h"

void Stream4Init(u_char *);
void PreprocFunction(Packet *);
void PreprocRestartFunction(int);
void PreprocCleanExitFunction(int);

/*  D E F I N E S  **************************************************/

/* normal TCP states */
#define CLOSED       0
#define LISTEN       1
#define SYN_RCVD     2
#define SYN_SENT     3
#define ESTABLISHED  4
#define CLOSE_WAIT   5
#define LAST_ACK     6
#define FIN_WAIT_1   7
#define CLOSING      8
#define FIN_WAIT_2   9
#define TIME_WAIT   10

/* extended states for fun stuff */
#define NMAP_FINGERPRINT_2S         30
#define NMAP_FINGERPRINT_NULL       31
#define NMAP_FINGERPRINT_UPSF       32
#define NMAP_FINGERPRINT_ZERO_ACK   33

#define ACTION_NOTHING                  0x00000000
#define ACTION_FLUSH_SERVER_STREAM      0x00000001
#define ACTION_FLUSH_CLIENT_STREAM      0x00000002
#define ACTION_DROP_SESSION             0x00000004
#define ACTION_ACK_SERVER_DATA          0x00000008
#define ACTION_ACK_CLIENT_DATA          0x00000010
#define ACTION_DATA_ON_SYN              0x00000020
#define ACTION_SET_SERVER_ISN           0x00000040
#define ACTION_COMPLETE_TWH             0x00000080
#define ACTION_ALERT_NMAP_FINGERPRINT   0x00000100
#define ACTION_INC_PORT                 0x00000200

#define SERVER_PACKET   0
#define CLIENT_PACKET   1

#define FROM_SERVER     0
#define FROM_CLIENT     1

#define PRUNE_QUANTA    30    /* seconds to timeout a session */
#define STREAM4_MEMORY_CAP     8388608  /* 8MB */
#define STREAM4_TTL_LIMIT 5 /* default for TTL Limit */

#define STATS_HUMAN_READABLE   1
#define STATS_MACHINE_READABLE 2
#define STATS_BINARY           3
#define STATS_DB               4

#define STATS_MAGIC  0xDEAD029A   /* magic for the binary stats file */

#define REVERSE     0
#define NO_REVERSE  1

#define METHOD_FAVOR_NEW  0x01
#define METHOD_FAVOR_OLD  0x02

/* We must twiddle to align the offset the ethernet header and align
   the IP header on solaris -- maybe this will work on HPUX too.
*/
#if defined (SOLARIS) || defined (SUNOS) || defined (HPUX)
#define SPARC_TWIDDLE       2
#else
#define SPARC_TWIDDLE       0
#endif

/* random array of flush points */

#define FCOUNT 64

static u_int8_t flush_points[FCOUNT] = { 128, 217, 189, 130, 240, 221, 134, 129,
                                         250, 232, 141, 131, 144, 177, 201, 130,
                                         230, 190, 177, 142, 130, 200, 173, 129,
                                         250, 244, 174, 151, 201, 190, 180, 198,
                                         220, 201, 142, 185, 219, 129, 194, 140,
                                         145, 191, 197, 183, 199, 220, 231, 245,
                                         233, 135, 143, 158, 174, 194, 200, 180,
                                         201, 142, 153, 187, 173, 199, 143, 201 };



/* How often to flush if using STATS_DB */
#define FLUSH_DELAY 30000

/*  D A T A   S T R U C T U R E S  **********************************/
typedef struct _Stream4Data
{
    char stream4_active;

    char stateful_inspection_flag;
    u_int32_t timeout;
    char state_alerts;
    char evasion_alerts;
    u_int32_t memcap;

    char log_flushed_streams;

    char ps_alerts;

    char track_stats_flag;
    char *stats_file;
    
    u_int32_t last_prune_time;

    char reassemble_client;
    char reassemble_server;
    char reassembly_alerts;
    u_int8_t assemble_ports[65536];
    
    u_int8_t  stop_traverse;
    u_int32_t stop_seq;
    
    u_int8_t  min_ttl;   /* min TTL we'll accept to insert a packet */
    u_int8_t  ttl_limit; /* the largest difference we'll accept in the
                            course of a TTL conversation */
    u_int16_t path_mtu;  /* max segment size we'll accept */

    u_int8_t  reassy_method;

    u_int32_t ps_memcap;
    char asynchronous_link; /* used when you can only see part of the conversation
                               it can't be anywhere NEAR as robust     
                            */

} Stream4Data;

typedef struct _StreamPacketData
{
    ubi_trNode Node;
    u_int8_t *pkt;
    u_int8_t *payload;
    SnortPktHeader pkth;
    u_int32_t seq_num;
    u_int16_t payload_size;
    u_int16_t pkt_size;
    u_int32_t cksum;
    u_int8_t  chuck;   /* mark the spd for chucking if it's 
                        * been reassembled 
                        */
} StreamPacketData;

typedef struct _BuildData
{
    Stream *stream;
    u_int8_t *buf;
    u_int16_t total_size;
    /* u_int32_t build_flags; -- reserved for the day when we generate 1 stream event and log the stream */
} BuildData;

typedef struct _BinStats
{
    u_int32_t start_time;
    u_int32_t end_time;
    u_int32_t sip;
    u_int32_t cip;
    u_int16_t sport;
    u_int16_t cport;
    u_int32_t spackets;
    u_int32_t cpackets;
    u_int32_t sbytes;
    u_int32_t cbytes;
} BinStats;

typedef struct _DbStats
{
    long xid;
    char start_time[20];
    char end_time[20];
    u_int32_t sip;
    u_int32_t cip;
    u_int16_t sport;
    u_int16_t cport;
    u_int32_t spackets;
    u_int32_t cpackets;
    u_int32_t sbytes;
    u_int32_t cbytes;
    struct _DbStats *next;
} DbStats;


typedef struct _StatsLog
{
    FILE *fp;
    char *filename;

} StatsLog;

typedef struct _StatsLogHeader
{
    u_int32_t magic;
    u_int32_t version_major;
    u_int32_t version_minor;
    u_int32_t timezone;
} StatsLogHeader;


typedef Session *SessionPtr;

StatsLog *stats_log;

/* splay tree root data */
static ubi_trRoot s_cache;
static ubi_trRootPtr RootPtr = &s_cache;

u_int32_t safe_alloc_faults;

/* we keep a stream packet queued up and ready to go for reassembly */
Packet *stream_pkt;

/*  G L O B A L S  **************************************************/
/* external globals from rules.c */
extern char *file_name;
extern int file_line;
FILE *session_log;
Stream4Data s4data;
u_int32_t stream4_memory_usage;
u_int32_t ps_memory_usage;
extern int do_detect;
DbStats *dbsPtr = NULL;
long LastFlushTime;
char DBLOGDIR[STD_BUF];


/*  P R O T O T Y P E S  ********************************************/
void *SafeAlloc(unsigned long, int, Session *);
void ParseStream4Args(char *);
void Stream4InitReassembler(u_char *);
void ReassembleStream4(Packet *);
Session *GetSession(Packet *);
Session *CreateNewSession(Packet *, u_int32_t, u_int32_t);
void DropSession(Session *);
void DeleteSession(Session *, u_int32_t);
void DeleteSpd(ubi_trRootPtr, int);
int GetDirection(Session *, Packet *);
void Stream4CleanExitFunction(int, void *);
void Stream4RestartFunction(int, void *);
void PrintSessionCache();
int CheckRst(Session *, int, u_int32_t, Packet *);
int PruneSessionCache(u_int32_t, int, Session *);
void StoreStreamPkt(Session *, Packet *, u_int32_t);
void FlushStream(Stream *, Packet *, int);
void InitStream4Pkt();
void BuildPacket(Stream *, u_int32_t, Packet *, int);
int CheckPorts(u_int16_t, u_int16_t);
void PortscanWatch(Session *, u_int32_t);
void PortscanDeclare(Packet *);
void AddNewTarget(ubi_trRootPtr, u_int32_t, u_int16_t, u_int8_t);
void AddNewPort(ubi_trRootPtr, u_int16_t, u_int8_t);
int LogStream(Stream *);
void WriteSsnStats(BinStats *);
void OpenStatsFile();
static int RetransTooFast(struct timeval *a, struct timeval *b);

DbStats *AddDbStats(DbStats * dbsPtr, Session * ssn);
DbStats *FlushDbStats(DbStats * dbsPtr);

/*
  Here is where we separate which functions will be called in the
  normal case versus in the asynchronus state

*/
   
int UpdateState(Session *, Packet *, u_int32_t); 
int UpdateStateAsync(Session *, Packet *, u_int32_t);

static void TcpAction(Session *ssn, Packet *p, int action, int direction, 
                      u_int32_t pkt_seq, u_int32_t pkt_ack);
static void TcpActionAsync(Session *ssn, Packet *p, int action, int direction, 
                           u_int32_t pkt_seq, u_int32_t pkt_ack);

long TimeMilliseconds()
{
    struct timeval  tv;
    gettimeofday(&tv, NULL);

    return (long)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

DbStats *AddDbStats(DbStats *dbsPtr, Session *ssn)
{

  DbStats *dbs = dbsPtr;
  register int s;
  struct tm *lt;
  struct tm *et;

  if (dbsPtr != NULL)
  {

    while (dbsPtr->next != NULL)
      dbsPtr = dbsPtr->next;

    dbsPtr->next = (DbStats *) malloc (sizeof (DbStats));
    dbsPtr=dbsPtr->next;
    dbsPtr->next = NULL;

    dbsPtr->xid = TimeMilliseconds();

    lt = localtime((time_t *) &ssn->start_time);
    s = (ssn->start_time + thiszone) % 86400;
    sprintf(dbsPtr->start_time, "%02d-%02d-%02d %02d:%02d:%02d", 1900 + lt->tm_year,
           lt->tm_mon+1, lt->tm_mday, s/3600, (s%3600)/60, s%60);

    et = localtime((time_t *) &ssn->last_session_time);
    s = (ssn->last_session_time + thiszone) % 86400;
    sprintf(dbsPtr->end_time, "%02d-%02d-%02d %02d:%02d:%02d", 1900 + et->tm_year,
               et->tm_mon+1, et->tm_mday, s/3600, (s%3600)/60, s%60);

    dbsPtr->sip = ntohl(ssn->server.ip);
    dbsPtr->cip = ntohl(ssn->client.ip);
    dbsPtr->sport = ssn->server.port;
    dbsPtr->cport = ssn->client.port;
    dbsPtr->spackets = ssn->server.pkts_sent;
    dbsPtr->cpackets = ssn->client.pkts_sent;
    dbsPtr->sbytes = ssn->server.bytes_sent;
    dbsPtr->cbytes = ssn->client.bytes_sent;
    return dbs;

  } else {

    dbsPtr = (DbStats *) malloc (sizeof (DbStats));
    dbsPtr->next = NULL;

    dbsPtr->xid = TimeMilliseconds();

    lt = localtime((time_t *) &ssn->start_time);
    s = (ssn->start_time + thiszone) % 86400;
    sprintf(dbsPtr->start_time, "%02d-%02d-%02d %02d:%02d:%02d", 1900 + lt->tm_year,
           lt->tm_mon+1, lt->tm_mday, s/3600, (s%3600)/60, s%60);

    et = localtime((time_t *) &ssn->last_session_time);
    s = (ssn->last_session_time + thiszone) % 86400;
    sprintf(dbsPtr->end_time, "%02d-%02d-%02d %02d:%02d:%02d", 1900 + et->tm_year,
               et->tm_mon+1, et->tm_mday, s/3600, (s%3600)/60, s%60);

    dbsPtr->sip = ntohl(ssn->server.ip);
    dbsPtr->cip = ntohl(ssn->client.ip);
    dbsPtr->sport = ssn->server.port;
    dbsPtr->cport = ssn->client.port;
    dbsPtr->spackets = ssn->server.pkts_sent;
    dbsPtr->cpackets = ssn->client.pkts_sent;
    dbsPtr->sbytes = ssn->server.bytes_sent;
    dbsPtr->cbytes = ssn->client.bytes_sent;
    return dbsPtr;
  }
}

DbStats *FlushDbStats(DbStats *dbsPtr)
{

      char dblogfile[STD_BUF];
      FILE *dbstats_log;

      snprintf(dblogfile, STD_BUF, "%s/ssn_log.%lu",
        DBLOGDIR, TimeMilliseconds());

      if((dbstats_log = fopen(dblogfile, "a")) == NULL )
         FatalError("Unable to write to '%s': %s\n", dblogfile, strerror(errno));

      while (dbsPtr != NULL)
      {
        DbStats *tmp;
        fprintf(dbstats_log, "%lu|%s|%s|%u|%u|%d|%d|%u|%u|%u|%u\n",
          dbsPtr->xid, dbsPtr->start_time, dbsPtr->end_time, dbsPtr->cip,
          dbsPtr->sip, dbsPtr->cport, dbsPtr->sport,
          dbsPtr->cpackets,
          dbsPtr->spackets, dbsPtr->cbytes, dbsPtr->sbytes);

       tmp = dbsPtr->next;
       free(dbsPtr);
       dbsPtr = tmp;
      }

    fclose(dbstats_log);
    LastFlushTime = TimeMilliseconds();
    return dbsPtr;
}


static int CompareFunc(ubi_trItemPtr ItemPtr, ubi_trNodePtr NodePtr)
{
    Session *nSession;
    Session *iSession; 

    nSession = ((Session *)NodePtr);
    iSession = (Session *)ItemPtr;

    if(nSession->server.ip < iSession->server.ip) return 1;
    else if(nSession->server.ip > iSession->server.ip) return -1;

    if(nSession->client.ip < iSession->client.ip) return 1;
    else if(nSession->client.ip > iSession->client.ip) return -1;
        
    if(nSession->server.port < iSession->server.port) return 1;
    else if(nSession->server.port > iSession->server.port) return -1;

    if(nSession->client.port < iSession->client.port) return 1;
    else if(nSession->client.port > iSession->client.port) return -1;

    return 0;
}

/* 
 * Returns 1 if the difference between a and b is less than 1.001 *
 *         0 otherwise
 *
 * The Value of 1. was taken from p. 2
 */

#define ONE_SEC_IN_USEC 10000
#define STREAM4_RXIT_THRESH 10100

static int RetransTooFast(struct timeval *a, struct timeval *b)
{
    struct timeval *tmp;
    long tmp_t;
    /* normalize so that A is always previous to B */
    if(a->tv_sec == b->tv_sec) {
        return 1;
    }
    else if(a->tv_sec > b->tv_sec)
    {
        tmp = b;
        b = a;
        a = tmp;
    }

    tmp_t = b->tv_sec - a->tv_sec;
    /* ok A is now previous to B */
    if(tmp_t > 1) {
        return 0; /* after 2 seconds, we could retranmit no problem! */
    }
    else if(tmp_t != 1) {
        LogMessage("Time just jumped around.....\n");
        return 1;
    }

    /* tmp_t is in seconds... -- convert to microseconds */
    tmp_t = tmp_t * ONE_SEC_IN_USEC;
    
    tmp_t = b->tv_usec - a->tv_usec + tmp_t;

    if(tmp_t >= STREAM4_RXIT_THRESH) {
        return 1;
    }

    return 0;
}

static int DataCompareFunc(ubi_trItemPtr ItemPtr, ubi_trNodePtr NodePtr)
{
    StreamPacketData *nStream;
    StreamPacketData *iStream; 

    nStream = ((StreamPacketData *)NodePtr);
    iStream = ((StreamPacketData *)ItemPtr);

    if(nStream->seq_num < iStream->seq_num) return 1;
    else if(nStream->seq_num > iStream->seq_num) return -1;

    return 0;
}


static void KillSpd(ubi_trNodePtr NodePtr)
{
    StreamPacketData *tmp;

    tmp = (StreamPacketData *)NodePtr;

    stream4_memory_usage -= tmp->pkt_size;
    free(tmp->pkt);

    stream4_memory_usage -= sizeof(StreamPacketData);
    free(tmp);
}


static void TraverseFunc(ubi_trNodePtr NodePtr, void *build_data)
{
    Stream *s;
    StreamPacketData *spd;
    BuildData *bd;
    u_int8_t *buf;
    int trunc_size;
    int offset = 0;

    if(s4data.stop_traverse)
        return;

    spd = (StreamPacketData *) NodePtr;
    bd = (BuildData *) build_data;
    s = bd->stream;
    buf = bd->buf;

    /* don't reassemble if we're before the start sequence number or 
     * after the last ack'd byte
     */
    if(spd->seq_num < s->base_seq || spd->seq_num > s->last_ack) {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "not reassembling because"
                                " we're (%u) before isn(%u) or after last_ack(%u)\n",
                                spd->seq_num, s->base_seq, s->last_ack););
        return;
    }

    /* if it's in bounds... */
    if(spd->seq_num >= s->base_seq && spd->seq_num >= s->next_seq &&
       (spd->seq_num+spd->payload_size) <= s->last_ack)
    {
        offset = spd->seq_num - s->base_seq;
        
        s->next_seq = spd->seq_num + spd->payload_size;

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Copying %d bytes into buffer, "
                                "offset %d, buf %p\n", spd->payload_size, offset, 
                                buf););

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "spd->seq_num (%u)  s->last_ack (%u) s->base_seq(%u) size: (%u) s->next_seq(%u), offset(%u)\n",
                                spd->seq_num, s->last_ack, s->base_seq,
                                spd->payload_size, s->next_seq, offset));

        memcpy(buf+offset, spd->payload, spd->payload_size);

        pc.rebuilt_segs++;

        spd->chuck = 1;
        bd->total_size += spd->payload_size;
    } 
    else if(spd->seq_num >= s->base_seq && 
            spd->seq_num < s->last_ack &&
            spd->seq_num + spd->payload_size > s->last_ack)
    {
        /*
         *  if it starts in bounds and hasn't been completely ack'd, 
         *  truncate the last piece and copy it in 
         */
        trunc_size = s->last_ack - spd->seq_num; 

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Truncating overlap of %d bytes\n", 
                                spd->seq_num + spd->payload_size - s->last_ack);
                   DebugMessage(DEBUG_STREAM, "    => trunc info seq: 0x%X   "
                                "size: %d  last_ack: 0x%X\n", 
                                spd->seq_num, spd->payload_size, s->last_ack);
                   );

        offset = spd->seq_num - s->base_seq;

        if(trunc_size < (65500-offset) && trunc_size > 0)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Copying %d bytes into buffer, "
                                    "offset %d, buf %p\n", trunc_size, offset, 
                                    buf););
            memcpy(buf+offset, spd->payload, trunc_size);
            pc.rebuilt_segs++;
            bd->total_size += trunc_size;
        }
        else
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Woah, got bad TCP segment "
                                    "trunctation value (%d)\n", trunc_size););
        }

        spd->chuck = 1;
    }
    else if(spd->seq_num < s->base_seq && 
            spd->seq_num+spd->payload_size > s->base_seq)
    {
        /* case where we've got a segment that wasn't completely ack'd 
         * last time it was processed, do a partial copy into the buffer
         */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Incompleted segment, copying up "
                                "to last-ack\n"););

        /* calculate how much un-ack'd data to copy */
        trunc_size = (spd->seq_num+spd->payload_size) - s->base_seq;

        /* figure out where in the original data payload to start copying */
        offset = s->base_seq - spd->seq_num;
        
        if(trunc_size < 65500 && trunc_size > 0)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Copying %d bytes into buffer, "
                                    "offset %d, buf %p\n", trunc_size, offset, 
                                    buf););
            memcpy(buf, spd->payload+offset, trunc_size);
            pc.rebuilt_segs++;
            bd->total_size += trunc_size;
        }
        else
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Woah, got bad TCP segment "
                                    "trunctation value (%d)\n", trunc_size););
        }
    }
    else if(spd->seq_num < s->base_seq)
    {
        /* ignore this segment, we've already looked at it */
        return;
    }
    else if(spd->seq_num > s->last_ack)
    {
        /* we're all done, we've walked past the end of the ACK'd data */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "   => Segment is past last ack'd data, "
                                "ignoring for now...\n");
                   DebugMessage(DEBUG_STREAM,  "        => (%d bytes @ seq 0x%X, "
                                "ack: 0x%X)\n", spd->payload_size, spd->seq_num, s->last_ack);
                   );

        /* since we're reassembling in order, once we hit an overflow condition
         * let's stop trying for now
         */
        s4data.stop_traverse = 1;
        s4data.stop_seq = spd->seq_num;
    }
    else if(spd->seq_num < s->next_seq)
    {
        if(s4data.evasion_alerts)
        {
            Event event;
            Packet p;
            bzero(&p, sizeof(Packet));

            /* go through and generate enough of a packet to generate an alert off of */
            (*grinder)(&p, (struct pcap_pkthdr *) &spd->pkth, spd->pkt);
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_MULTIPLE_ACKED, 1, 0, 5, 0);
            CallAlertFuncs(&p, STREAM4_MULTIPLE_ACKED_STR, NULL, &event);
            CallLogFuncs(&p, STREAM4_MULTIPLE_ACKED_STR, NULL, &event);
        }
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "The seq_num is less than it should have been\n"););
        return;
    }
    else
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "Ended up in the default case somehow.. !\n"
                                "spd->seq_num(%u) s->next_seq(%u)\n"
                                ););
        
    }

     

} 



void SegmentCleanTraverse(Stream *s)
{
    StreamPacketData *spd;
    StreamPacketData *foo;

    spd = (StreamPacketData *) ubi_btFirst((ubi_btNodePtr)s->dataPtr);

    while(spd != NULL)
    {
        if(spd->chuck == 1 || s->last_ack > (spd->seq_num+spd->payload_size))
        {
            StreamPacketData *savspd = spd;
            spd = (StreamPacketData *) ubi_btNext((ubi_btNodePtr)spd);
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "chucking used segment\n"););
            foo = (StreamPacketData *) ubi_sptRemove(s->dataPtr, 
                                                     (ubi_btNodePtr) savspd);
            stream4_memory_usage -= foo->pkt_size;
            free(foo->pkt);
            stream4_memory_usage -= sizeof(StreamPacketData);
            free(foo);
        }
        else
        {
            spd = (StreamPacketData *) ubi_btNext((ubi_btNodePtr)spd);
        }
    }
}

/* XXX: this will be removed as we clean up the modularization */
void DirectLogTcpdump(struct pcap_pkthdr *, u_int8_t *);

static void LogTraverse(ubi_trNodePtr NodePtr, void *foo)
{
    StreamPacketData *spd;

    spd = (StreamPacketData *) NodePtr;
    /* XXX: modularization violation */
    DirectLogTcpdump((struct pcap_pkthdr *)&spd->pkth, spd->pkt); 
}



void *SafeAlloc(unsigned long size, int tv_sec, Session *ssn)
{
    void *tmp;

    stream4_memory_usage += size;

    /* if we use up all of our RAM, try to free up some stale sessions */
    if(stream4_memory_usage > s4data.memcap)
    {
        pc.str_mem_faults++;

        if(!PruneSessionCache((u_int32_t)tv_sec, 0, ssn))
        {
            /* if we can't prune due to time, just nuke 5 random sessions */
            PruneSessionCache(0, 5, ssn);
        }
    }

    tmp = (void *) calloc(size, sizeof(char));

    if(tmp == NULL)
    {
        FatalError("Unable to allocate memory! (%lu bytes in use)\n", 
                   (unsigned long)stream4_memory_usage);
    }

    return tmp;
}


/*
 * Function: SetupStream4()
 *
 * Purpose: Registers the preprocessor keyword and initialization 
 *          function into the preprocessor list.  This is the function that
 *          gets called from InitPreprocessors() in plugbase.c.
 *
 * Arguments: None.
 *
 * Returns: void function
 */
void SetupStream4()
{
    /* link the preprocessor keyword to the init function in 
       the preproc list */
    RegisterPreprocessor("stream4", Stream4Init);
    RegisterPreprocessor("stream4_reassemble", Stream4InitReassembler);

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "Preprocessor: Stream4 is setup...\n"););
}


/*
 * Function: Stream4Init(u_char *)
 *
 * Purpose: Calls the argument parsing function, performs final setup on data
 *          structs, links the preproc function into the function list.
 *
 * Arguments: args => ptr to argument string
 *
 * Returns: void function
 */
void Stream4Init(u_char *args)
{
    char logfile[STD_BUF];

    s4data.stream4_active = 1;
    pv.stateful = 1;
    s4data.memcap = STREAM4_MEMORY_CAP;

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "log_dir is %s\n", pv.log_dir););

    /* parse the argument list from the rules file */
    ParseStream4Args(args);

    snprintf(logfile, STD_BUF, "%s%s/%s",
             chrootdir == NULL ? "" : chrootdir, pv.log_dir, "session.log");
    
    if(s4data.track_stats_flag)
    {
        if((session_log = fopen(logfile, "a+")) == NULL)
        {
            FatalError("Unable to write to \"%s\": %s\n", logfile, 
                       strerror(errno));
        }
    }

    s4data.last_prune_time = 0;
    
    stream_pkt = (Packet *) SafeAlloc(sizeof(Packet), 0, NULL);
    InitStream4Pkt();

    /* tell the rest of the program that we're stateful */
    snort_runtime.capabilities.stateful_inspection = 1;

    (void)ubi_trInitTree(RootPtr,       /* ptr to the tree head */
                         CompareFunc,   /* comparison function */
                         0);            /* don't allow overwrites/duplicates */

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "Preprocessor: Stream4 Initialized\n"););

    /* Set the preprocessor function into the function list */
    AddFuncToPreprocList(ReassembleStream4);
    AddFuncToCleanExitList(Stream4CleanExitFunction, NULL);
    AddFuncToRestartList(Stream4RestartFunction, NULL);

    LastFlushTime = TimeMilliseconds();
}

void DisplayStream4Config(void) 
{
    LogMessage("Stream4 config:\n");
    LogMessage("    Stateful inspection: %s\n", 
               s4data.stateful_inspection_flag ? "ACTIVE": "INACTIVE");
    LogMessage("    Session statistics: %s\n", 
               s4data.track_stats_flag ? "ACTIVE":"INACTIVE");
    LogMessage("    Session timeout: %d seconds\n", s4data.timeout);
    LogMessage("    Session memory cap: %lu bytes\n", (unsigned long)s4data.memcap);
    LogMessage("    State alerts: %s\n", 
               s4data.state_alerts ? "ACTIVE":"INACTIVE");
    LogMessage("    Evasion alerts: %s\n", 
               s4data.evasion_alerts ? "ACTIVE":"INACTIVE");
    LogMessage("    Scan alerts: %s\n", 
               s4data.ps_alerts ? "ACTIVE":"INACTIVE");
    LogMessage("    Log Flushed Streams: %s\n",
               s4data.log_flushed_streams ? "ACTIVE":"INACTIVE");
    LogMessage("    MinTTL: %d\n", s4data.min_ttl);
    LogMessage("    TTL Limit: %d\n", s4data.ttl_limit);
    LogMessage("    Async Link: %d\n", s4data.asynchronous_link);
}


/*
 * Function: ParseStream4Args(char *)
 *
 * Purpose: Process the preprocessor arguements from the rules file and 
 *          initialize the preprocessor's data struct.  This function doesn't
 *          have to exist if it makes sense to parse the args in the init 
 *          function.
 *
 * Arguments: args => argument list
 *
 * Returns: void function
 */
void ParseStream4Args(char *args)
{
    char **toks;
    int num_toks;
    int i;
    char *index;
    char **stoks = NULL;
    int s_toks;

    s4data.timeout = PRUNE_QUANTA;
    s4data.memcap = STREAM4_MEMORY_CAP;
    s4data.stateful_inspection_flag = 1;
    s4data.state_alerts = 0;
    s4data.evasion_alerts = 1;
    s4data.ps_alerts = 0;
    s4data.reassemble_client = s4data.reassemble_server = 0;
    s4data.log_flushed_streams = 0;
    s4data.min_ttl = 1;
    s4data.path_mtu = 1460;
    s4data.ttl_limit = STREAM4_TTL_LIMIT;
    s4data.asynchronous_link = 0;
    
    /* if no arguments, go ahead and return */
    if(args == NULL || args[0] == '\0')
    {
        if(!pv.quiet_flag) {
            DisplayStream4Config();
        }
        return;
    }

    i=0;

    toks = mSplit(args, ",", 12, &num_toks, 0);
    
    while(i < num_toks)
    {
        index = toks[i];

        while(isspace((int)*index)) index++;

        stoks = mSplit(index, " ", 4, &s_toks, 0);

        if(!strcasecmp(stoks[0], "noinspect"))
        {
            s4data.stateful_inspection_flag = 0;
        }
        else if(!strcasecmp(stoks[0], "asynchronous_link"))
        {
            s4data.asynchronous_link = 1;
        }
        else if(!strcasecmp(stoks[0], "keepstats"))
        {
            s4data.track_stats_flag = STATS_HUMAN_READABLE;

            if(s_toks > 1)
            {
                if(!strcasecmp(stoks[1], "machine"))
                {
                    s4data.track_stats_flag = STATS_MACHINE_READABLE;
                }
                else if(!strcasecmp(stoks[1], "binary"))
                {
                    s4data.track_stats_flag = STATS_BINARY;
                    stats_log = (StatsLog *) calloc(sizeof(StatsLog), 
                                                    sizeof(char));
                    stats_log->filename = strdup("snort-unified.stats");
                    OpenStatsFile();
                } 
                else if(!strcasecmp(stoks[1], "db"))
                {
                    if(s_toks > 2)
                    {
                      s4data.track_stats_flag = STATS_DB;
                      snprintf(DBLOGDIR,STD_BUF, "%s", stoks[2]);
                      if( access(DBLOGDIR, 2) != 0)
                        FatalError("ERROR: ssn log dir '%s' does not exist\n", DBLOGDIR);
                    } else {
                      ErrorMessage("Stats mode \"db\" requires a log dir.\n");
                      s4data.track_stats_flag=0;
                    }
                }
                else
                {
                    ErrorMessage("Bad stats mode for stream4, ignoring\n");
                    s4data.track_stats_flag = 0;
                }
            }
        }
        else if(!strcasecmp(stoks[0], "detect_scans"))
        {
            s4data.ps_alerts = 1;
        }
        else if(!strcasecmp(stoks[0], "log_flushed_streams"))
        {
            s4data.log_flushed_streams = 1;
        }
        else if(!strcasecmp(stoks[0], "detect_state_problems"))
        {
            s4data.state_alerts = 1;
        }
        else if(!strcasecmp(stoks[0], "disable_evasion_alerts"))
        {
            s4data.evasion_alerts = 0;
        }

        else if(!strcasecmp(stoks[0], "timeout"))
        {
            if(isdigit((int)stoks[1][0]))
            {
                s4data.timeout = atoi(stoks[1]);
            }
            else
            {
                LogMessage("WARNING %s(%d) => Bad timeout in config file, "
                           "defaulting to %d seconds\n", file_name, file_line, PRUNE_QUANTA);

                s4data.timeout = PRUNE_QUANTA;
            }
        }
        else if(!strcasecmp(stoks[0], "memcap"))
        {
            if(isdigit((int)stoks[1][0]))
            {
                s4data.memcap = atoi(stoks[1]);

                if(s4data.memcap < 16384)
                {
                    LogMessage("WARNING %s(%d) => Ludicrous (<16k) memcap "
                               "size, setting to default (%d bytes)\n", file_name, 
                               file_line, STREAM4_MEMORY_CAP);
                    
                    s4data.memcap = STREAM4_MEMORY_CAP;
                }
            }
            else
            {
                LogMessage("WARNING %s(%d) => Bad memcap in config file, "
                           "defaulting to %lu bytes\n", file_name, file_line, STREAM4_MEMORY_CAP);

                s4data.memcap = STREAM4_MEMORY_CAP;
            }
        }
        else if(!strcasecmp(stoks[0], "ttl_limit"))
        {
            if(isdigit((int)stoks[1][0]))
            {
                s4data.ttl_limit = atoi(stoks[1]);
            }
            else
            {
                LogMessage("WARNING %s(%d) => Bad TTL Limit"
                           "size, setting to default (%d\n", file_name, 
                           file_line, STREAM4_TTL_LIMIT);

                s4data.ttl_limit = STREAM4_TTL_LIMIT;
            }
        }
        else
        {
            FatalError("ERROR: Unknown stream4 options: %s\n", stoks[0]);
        }


        do
        {
            s_toks--;
            free(stoks[s_toks]);
        } while(s_toks);

        i++;
    }

    do
    {
        num_toks--;
        free(toks[num_toks]);
    }while(num_toks);

    if(!pv.quiet_flag)
    {
        DisplayStream4Config();
    }
}


void Stream4InitReassembler(u_char *args)
{
    char **toks;
    int num_toks;
    int i;
    int j = 0;
    char *index;

    if(s4data.stream4_active == 0)
    {
        FatalError("Please activate stream4 before trying to "
                   "activate stream4_reassemble\n");
    }

    s4data.reassembly_alerts = 1;
    s4data.reassemble_client = 1; 
    s4data.reassemble_server = 0;
    s4data.assemble_ports[21] = 1;
    s4data.assemble_ports[23] = 1;
    s4data.assemble_ports[25] = 1;
    s4data.assemble_ports[53] = 1;
    s4data.assemble_ports[80] = 1;
    s4data.assemble_ports[143] = 1;
    s4data.assemble_ports[110] = 1;
    s4data.assemble_ports[111] = 1;
    s4data.assemble_ports[513] = 1;
    s4data.assemble_ports[1433] = 1;
    s4data.reassy_method = METHOD_FAVOR_OLD;

    if(args == NULL)
    {
        s4data.reassemble_server = 0;

        if(!pv.quiet_flag)
        {
            LogMessage("No arguments to stream4_reassemble, setting "
                       "defaults:\n");
            LogMessage("     Reassemble client: ACTIVE\n");
            LogMessage("     Reassemble server: INACTIVE\n");
            LogMessage("     Reassemble ports: 21 23 25 53 80 143 110 111 "
                       "513\n");
            LogMessage("     Reassembly alerts: ACTIVE\n");
            LogMessage("     Reassembly method: FAVOR_OLD\n");
        }
        return;
    }
    else
    {
    }

    toks = mSplit(args, ",", 12, &num_toks, 0);

    i=0;

    while(i < num_toks)
    {
        index = toks[i];
        while(isspace((int)*index)) index++;

        if(!strncasecmp(index, "clientonly", 10))
        {
            s4data.reassemble_server = 0;
        }
        else if(!strncasecmp(index, "serveronly", 10))
        {
            s4data.reassemble_client = 0;
        }
        else if(!strncasecmp(index, "both", 4))
        {
            s4data.reassemble_client = 1;
            s4data.reassemble_server = 1;
        }
        else if(!strncasecmp(index, "noalerts", 8))
        {
            s4data.reassembly_alerts = 0;
        }
        else if(!strncasecmp(index, "favor_old", 9))
        {
            s4data.reassy_method = METHOD_FAVOR_OLD;
        }
        else if(!strncasecmp(index, "favor_new", 9))
        {
            s4data.reassy_method = METHOD_FAVOR_NEW;
        }
        else if(!strncasecmp(index, "ports", 5))
        {
            char **ports;
            int num_ports;
            char *port;
            int j = 0;
            u_int32_t portnum;

            for(j = 0;j<65535;j++)
            {
                s4data.assemble_ports[j] = 0;
            }

            ports = mSplit(args, " ", 40, &num_ports, 0);

            j = 0;

            while(j < num_ports)
            {
                port = ports[j];

                if(isdigit((int)port[0]))
                {
                    portnum = atoi(port);

                    if(portnum > 65535)
                    {
                        FatalError("ERROR %s(%d) => Bad port list to "
                                   "reassembler\n", file_name, file_line);
                    }

                    s4data.assemble_ports[portnum] = 1;
                }
                else if(!strncasecmp(port, "all", 3))
                {
                    memset(&s4data.assemble_ports, 1, 65536);
                }
                else if(!strncasecmp(port, "default", 7))
                {
                    s4data.assemble_ports[21] = 1;
                    s4data.assemble_ports[23] = 1;
                    s4data.assemble_ports[25] = 1;
                    s4data.assemble_ports[53] = 1;
                    s4data.assemble_ports[80] = 1;
                    s4data.assemble_ports[143] = 1;
                    s4data.assemble_ports[110] = 1;
                    s4data.assemble_ports[111] = 1;
                    s4data.assemble_ports[513] = 1;
                    s4data.assemble_ports[1433] = 1;
                }

                j++;
            }
        }
        else
        {
            FatalError("ERROR %s(%d) => Bad stream4_reassemble option "
                       "specified: \"%s\"\n", file_name, file_line, toks[i]);
        }

        i++;
    }

    if(!pv.quiet_flag)
    {
        LogMessage("Stream4_reassemble config:\n");
        LogMessage("    Server reassembly: %s\n", 
                   s4data.reassemble_server ? "ACTIVE": "INACTIVE");
        LogMessage("    Client reassembly: %s\n", 
                   s4data.reassemble_client ? "ACTIVE": "INACTIVE");
        LogMessage("    Reassembler alerts: %s\n", 
                   s4data.reassembly_alerts ? "ACTIVE": "INACTIVE");
        LogMessage("    Ports: "); 

        for(i=0;i<65536;i++)
        {
            if(s4data.assemble_ports[i])
            {
                LogMessage("%d ", i);
                j++;
            }

            if(j > 20)
            { 
                LogMessage("...\n");
                return;
            }
        }

        LogMessage("\n");
    }
}


/*
 * Function: PreprocFunction(Packet *)
 *
 * Purpose: Perform the preprocessor's intended function.  This can be
 *          simple (statistics collection) or complex (IP defragmentation)
 *          as you like.  Try not to destroy the performance of the whole
 *          system by trying to do too much....
 *
 * Arguments: p => pointer to the current packet data struct 
 *
 * Returns: void function
 */
void ReassembleStream4(Packet *p)
{
    Session *ssn;
    int action;
    int reassemble = 0;
    u_int32_t pkt_seq;
    u_int32_t pkt_ack;
    int direction;
#ifdef DEBUG
    static int pcount = 0;
    char flagbuf[9];

    pcount++;

    DebugMessage(DEBUG_STREAM, "pcount stream packet %d\n",pcount);
#endif
    
    if(p->tcph == NULL)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "p->tcph is null, returning\n"););
        return;
    }
    
    if(p->packet_flags & PKT_REBUILT_STREAM)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "REBUILT_STREAM returning\n"););
        return;
    }
    
    /* don't accept packets w/ bad checksums */
    if(p->csum_flags & CSE_IP || p->csum_flags & CSE_TCP)
    {
        DEBUG_WRAP(
                   u_int8_t c1 = (p->csum_flags & CSE_IP);
                   u_int8_t c2 = (p->csum_flags & CSE_TCP);
                   DebugMessage(DEBUG_STREAM, "IP CHKSUM: %d, CSE_TCP: %d",
                                c1,c2);
                   DebugMessage(DEBUG_STREAM, "Bad checksum returning\n");
                   );
        p->packet_flags |= PKT_STREAM_UNEST_UNI;
        return;
    }
    
    pc.tcp_stream_pkts++;
    
    reassemble = CheckPorts(p->sp, p->dp);
    
    /* if we're not doing stateful inspection... */
    if(s4data.stateful_inspection_flag == 0 && !reassemble)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "Not stateful inspection on this port, returning"););
        return;
    }

    DEBUG_WRAP(
               CreateTCPFlagString(p, flagbuf);
               DebugMessage(DEBUG_STREAM, "Got Packet 0x%X:%d ->  0x%X:%d %s",
                            p->iph->ip_src.s_addr,
                            p->sp,
                            p->iph->ip_dst.s_addr,
                            p->dp,
                            flagbuf);
               );
    
    pkt_seq = ntohl(p->tcph->th_seq);
    pkt_ack = ntohl(p->tcph->th_ack);
    
    /* see if we have a stream for this packet */
    ssn = GetSession(p);
    
    if(ssn == NULL)
    {
        /* TBD -- put this somewhere else. */

#ifdef USE_SF_STATS        
        sfPerf.sfBase.NewSessions++;
        sfPerf.sfBase.TotalSessions++;

        /* high water mark */
        if(sfPerf.sfBase.TotalSessions > sfPerf.sfBase.MaxSessions)
            sfPerf.sfBase.MaxSessions = sfPerf.sfBase.TotalSessions;
#endif  /* USE_SF_STATS */   
        

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Calling CreateNewSession()\n"););
        p->packet_flags |= PKT_FROM_CLIENT;
        ssn = CreateNewSession(p, pkt_seq, pkt_ack);
        
        p->packet_flags = PKT_STREAM_UNEST_UNI;
        
        if(ssn == NULL)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Got NULL pointer from "
                                    "CreateNewSession, returning\n"););
            return;
        }
    }    
    
    p->ssnptr = ssn;
    
    /* update the stream window size */
    if((direction = GetDirection(ssn, p)) == SERVER_PACKET)
    {
        p->packet_flags |= PKT_FROM_SERVER;
        ssn->client.win_size = ntohs(p->tcph->th_win);
        ssn->server.current_seq = pkt_seq;
        
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "server packet: %s\n", flagbuf););
    }
    else
    {
        p->packet_flags |= PKT_FROM_CLIENT;
        ssn->server.win_size = ntohs(p->tcph->th_win);
        ssn->client.current_seq = pkt_seq;
        
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "client packet: %s\n", flagbuf););
    }
    
    /* update the time for this session */
    ssn->last_session_time = p->pkth->ts.tv_sec;
    
    /* mark this packet is part of an established stream if possible */
    if(ssn->session_flags  & SSNFLAG_ESTABLISHED)
    {
        /* we know this stream is established, lets skip the other checks
           otherwise we get into clobbering our flags in the check below
        */
        p->packet_flags |= PKT_STREAM_EST;

        if(p->packet_flags & PKT_STREAM_UNEST_UNI)
        {
            p->packet_flags ^= PKT_STREAM_UNEST_UNI;
        }
            
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "Marking stream as established\n"););
#ifdef DEBUG
        if(p->packet_flags & PKT_FROM_CLIENT)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "pkt is from client\n"););
        } 

        if(p->packet_flags & PKT_FROM_SERVER)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "pkt is from server\n"););
        } 

        
#endif /*DEBUG*/
        
        
    } 

    if((s4data.asynchronous_link == 0) &&
       ((ssn->session_flags & (SSNFLAG_SEEN_SERVER|SSNFLAG_SEEN_CLIENT)) &&
        (ssn->server.state >= ESTABLISHED) &&
        (ssn->client.state >= ESTABLISHED)))
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "Stream is established!,ssnflags = 0x%p\n",
                                ssn->session_flags););

        /*
         * we've seen client and server traffic and it appears that the
         * TWH has already completed
         */
        p->packet_flags |= PKT_STREAM_EST;
        ssn->session_flags = SSNFLAG_ESTABLISHED;
    }
    else if((s4data.asynchronous_link == 1) &&
            ((((ssn->session_flags & SSNFLAG_SEEN_CLIENT)) &&
             (ssn->client.state >= ESTABLISHED)) ||
             (((ssn->session_flags & SSNFLAG_SEEN_SERVER)) &&
              (ssn->server.state >= ESTABLISHED))))
    {
        /*
         * we've seen client and server traffic and it appears that the
         * TWH has already completed
         *
         * either one side or the other has to be established -- fix for asynch link
         */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "Stream is established!,ssnflags = 0x%p\n",
                                ssn->session_flags););

        /*
         * we have to assume that the states are becoming established
         *
         * 
         */
        p->packet_flags |= PKT_STREAM_EST;
        ssn->session_flags = SSNFLAG_ESTABLISHED;
    }
    else
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Stream is not established!\n"););
        
        if(ssn->session_flags == (SSNFLAG_SEEN_SERVER|SSNFLAG_SEEN_CLIENT)) 
        {
            /*
             * we've seen packets in this stream from both the client and 
             * the server, but we haven't gotten through the three way
             * handshake
             */
            p->packet_flags |= PKT_STREAM_UNEST_BI;
        }
        else
        {
            /* 
             * this is the first time we've seen a packet 
             * from this stream
             */
            p->packet_flags |= PKT_STREAM_UNEST_UNI;
        }
    }
    
    /* go into the FSM to maintain stream state for this packet */
    
    if(s4data.asynchronous_link)
    {
        action = UpdateStateAsync(ssn, p, pkt_seq);
    }
    else
    {
        action = UpdateState(ssn, p, pkt_seq);
    }
    
    /* if this packet has data, maybe we should store it */
    if(p->dsize && reassemble)
    {
        StoreStreamPkt(ssn, p, pkt_seq);
    }
    
    /* 
     * resolve actions to be taken as indicated by state transitions or
     * normal traffic
     */

    if(s4data.asynchronous_link)
    {
        TcpActionAsync(ssn, p, action, direction, pkt_seq, pkt_ack);
    }
    else
    {
        TcpAction(ssn, p, action, direction, pkt_seq, pkt_ack);
    }

    
    PrintSessionCache();

    /*
     * For want of packet time at plugin initialization. (It only happens once.)
     * It wood be nice to get the first packet and do a little extra before
     * getting into the main snort processing loop.
     *   -- cpw
     */
    
    if (!s4data.last_prune_time)
    {
        s4data.last_prune_time = p->pkth->ts.tv_sec;
        return;
    }
    
    if( (u_int)(p->pkth->ts.tv_sec) > s4data.last_prune_time + s4data.timeout)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Prune time quanta exceeded, pruning "
                                "stream cache\n"););
        
        PruneSessionCache(p->pkth->ts.tv_sec, 0, NULL);
        s4data.last_prune_time = p->pkth->ts.tv_sec;
        
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Pruned for timeouts, %lu sessions "
                                "active, %lu bytes " "in use\n", 
                                (unsigned long int) ubi_trCount(RootPtr), stream4_memory_usage);
                   DebugMessage(DEBUG_STREAM, "Stream4 memory cap hit %lu times\n", 
                                safe_alloc_faults););
    }
    
    return;
}



int UpdateState(Session *ssn, Packet *p, u_int32_t pkt_seq)
{
    int direction;

    direction = GetDirection(ssn, p);


    switch(direction)
    {
        case FROM_SERVER:  /* packet came from the server */
            ssn->server.pkts_sent++;
            ssn->server.bytes_sent += p->dsize;


            if(!(ssn->session_flags & SSNFLAG_SEEN_SERVER))
            {
                if(ssn->server.state == ESTABLISHED)
                {
                    ssn->client.win_size = ntohs(p->tcph->th_win);
                }

                ssn->session_flags |= SSNFLAG_SEEN_SERVER;
            }

            switch(ssn->client.state)
            {
                case SYN_SENT:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Client State: SYN_SENT\n"););
                    if(p->tcph->th_flags & (TH_SYN|TH_ACK|TH_RES2))
                    {
                        ssn->client.state = ESTABLISHED;

                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: ESTABLISHED\n"););

                        /* ECN response */
                        if(ssn->session_flags & SSNFLAG_ECN_CLIENT_QUERY)
                        {
                            ssn->session_flags |= SSNFLAG_ECN_SERVER_REPLY;
                        }

                        return ACTION_SET_SERVER_ISN;
                    }
                    else if((p->tcph->th_flags & TH_NORESERVED) == (TH_SYN|TH_ACK))
                    {
                        ssn->client.state = ESTABLISHED;

                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: ESTABLISHED\n"););

                        return ACTION_SET_SERVER_ISN;
                    }
                    else if(p->tcph->th_flags & TH_RST)
                    {
                        /* check to make sure the RST is in window */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->client.state = CLOSED;
                            ssn->server.state = CLOSED;

                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transision: CLOSED\n"););

                            return ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }

                    return ACTION_NOTHING;


                case ESTABLISHED:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Client state: ESTABLISHED\n"););

                    if((p->tcph->th_flags == (TH_FIN|TH_ACK)))
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                    "Got FIN ACK (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->client.state = CLOSE_WAIT;
                        ssn->server.state = FIN_WAIT_1;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSE_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_1\n"););

                        return ACTION_ACK_CLIENT_DATA;
                    }
                    else if((p->tcph->th_flags == (TH_FIN|TH_ACK|TH_PUSH)))
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                    "Got FIN PSH ACK (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->client.state = CLOSE_WAIT;
                        ssn->server.state = FIN_WAIT_1;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSE_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_1\n"););

                        return ACTION_ACK_CLIENT_DATA;
                    }
                    else if(p->tcph->th_flags == TH_FIN)
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "Got FIN\n"););
                        ssn->client.state = CLOSE_WAIT;
                        ssn->server.state = FIN_WAIT_1;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSE_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_1\n"););
                        return ACTION_ACK_CLIENT_DATA;
                    }
                    else if((p->tcph->th_flags & TH_RST))
                    {
                        /* check seq numbers to avoid evasion */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_ACK_CLIENT_DATA |
                                ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        return ACTION_ACK_CLIENT_DATA;
                    }

                    return ACTION_NOTHING;

                case FIN_WAIT_1:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Client State: FIN_WAIT_1\n"););
                    if(p->tcph->th_flags & TH_RST)
                    {
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_ACK_CLIENT_DATA |
                                ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }
                    else if (p->tcph->th_flags & TH_ACK)
                    {
                        ssn->server.state = CLOSE_WAIT;
                        ssn->client.state = FIN_WAIT_2; 
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: FIN_WAIT_2\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: CLOSE_WAIT\n"););
                    }


                    return ACTION_NOTHING;

                case FIN_WAIT_2:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Client State: FIN_WAIT_2\n"););
                    if(p->tcph->th_flags == (TH_FIN|TH_ACK)) 
                    {
                        ssn->client.state = TIME_WAIT;
                        ssn->server.state = LAST_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: TIME_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: LAST_ACK\n"););

                        return ACTION_ACK_CLIENT_DATA;
                    }
                    else if(p->tcph->th_flags == TH_FIN)
                    {
                        ssn->client.state = TIME_WAIT;
                        ssn->server.state = LAST_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: TIME_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: LAST_ACK\n"););
                        return ACTION_ACK_CLIENT_DATA;
                    } 

                    return ACTION_NOTHING;

                case LAST_ACK:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Client state: LAST_ACK\n"););
                    if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->client.state = CLOSED;

                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "Client Transition: CLOSED\n"););

                        return ACTION_FLUSH_CLIENT_STREAM | 
                            ACTION_FLUSH_SERVER_STREAM | 
                            ACTION_DROP_SESSION;
                    }
                    return ACTION_NOTHING;

                case CLOSE_WAIT:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Client state: CLOSE_WAIT\n"););
                    if(p->tcph->th_flags == TH_RST)
                    {
                        /* check window for evasive RSTs */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }                    
                    else if(p->tcph->th_flags == (TH_ACK|TH_PUSH|TH_FIN))
                    {
                        ssn->server.state = FIN_WAIT_2;
                        ssn->client.state = LAST_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: LAST_ACK\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_2\n"););

                        return ACTION_ACK_CLIENT_DATA;
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->server.state = FIN_WAIT_2;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_2\n"););
                        return ACTION_ACK_CLIENT_DATA;
                    }



                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_2S:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Client state: "
                                "NMAP_FINGERPRINT_2S\n"););
                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_NULL:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Client state: "
                                "NMAP_FINGERPRINT_NULL\n"););
                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_UPSF:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Client state: "
                                "NMAP_FINGERPRINT_UPSF\n"););

                case NMAP_FINGERPRINT_ZERO_ACK:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Client state: "
                                "NMAP_FINGERPRINT_ZERO_ACK\n"););
                    return ACTION_DROP_SESSION;
            }

            break;

        case FROM_CLIENT:
            ssn->client.pkts_sent++;
            ssn->client.bytes_sent += p->dsize;

            if(!(ssn->session_flags & SSNFLAG_SEEN_CLIENT))
            {
                ssn->session_flags |= SSNFLAG_SEEN_CLIENT;
            }

            switch(ssn->server.state)
            {
                case LISTEN:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: LISTEN\n"););

                    /* only valid packet for this state is a SYN...
                       or SYN + ECN crap.

                       Revised: As long as it's got a SYN and not a
                       RST, Lets try to make the session start.  It
                       may just timeout -- cmg
                    */
                    if((p->tcph->th_flags & TH_SYN) &&
                       !(p->tcph->th_flags & TH_RST))
                    {
                        ssn->server.state = SYN_RCVD;
                        ssn->client.state = SYN_SENT;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: SYN_SENT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: SYN_RCVD\n"););
                    }

                    if(p->dsize == 0)
                        return ACTION_NOTHING;
                    else
                        return ACTION_DATA_ON_SYN;

                case SYN_RCVD:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Server state: SYN_RCVD\n"););
                    if(p->tcph->th_flags & TH_RST)
                    {
                        /* check window for evasive RSTs */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;

                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_DROP_SESSION;
                        }
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->server.state = ESTABLISHED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: ESTABLISHED\n"););
                        return ACTION_COMPLETE_TWH;
                    }

                    return ACTION_NOTHING;
                case ESTABLISHED:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Server state: ESTABLISHED\n"););
                    if(p->tcph->th_flags == (TH_FIN|TH_ACK))
                    {
                        ssn->client.state = FIN_WAIT_1;
                        ssn->server.state = CLOSE_WAIT;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: FIN_WAIT_1\n"););

                        return ACTION_ACK_SERVER_DATA;
                    }
                    else if(p->tcph->th_flags == (TH_FIN|TH_ACK|TH_PUSH))
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "Got FIN PSH ACK (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->client.state = CLOSE_WAIT;
                        ssn->server.state = FIN_WAIT_1;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSE_WAIT\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_1\n"););

                        return ACTION_ACK_SERVER_DATA;
                    }
                    else if(p->tcph->th_flags & TH_RST)
                    {
                        /* check window for evasive RSTs */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            /* check seq numbers to avoid evasion */
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););
                            return ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        return ACTION_ACK_SERVER_DATA;
                    }

                    return ACTION_NOTHING;

                case LAST_ACK:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: LAST_ACK\n"););
                    if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->server.state = CLOSED;

                        return ACTION_FLUSH_CLIENT_STREAM | 
                            ACTION_FLUSH_SERVER_STREAM | 
                            ACTION_DROP_SESSION;
                    }
                    return ACTION_NOTHING;


                case FIN_WAIT_1:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: FIN_WAIT_1\n"););
                    if(p->tcph->th_flags == (TH_ACK|TH_FIN))
                    {
                        ssn->client.state = LAST_ACK;
                        ssn->server.state = FIN_WAIT_2;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: LAST_ACK\n"););
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT2\n"););
                        
                        return ACTION_ACK_SERVER_DATA;
                    }
                    
                    else if(p->tcph->th_flags & TH_RST)
                    {
                        /* check window for evasive RSTs */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }
                    else if(p->tcph->th_flags == TH_ACK)
                    {
                        ssn->server.state = FIN_WAIT_2;
                        ssn->client.state = CLOSE_WAIT;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: FIN_WAIT_2\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSE_WAIT\n"););
                        return ACTION_ACK_SERVER_DATA;                        
                    }

                    return ACTION_NOTHING;

                case FIN_WAIT_2:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: FIN_WAIT_2\n"););
                    if(p->tcph->th_flags == (TH_FIN|TH_ACK))
                    {
                        ssn->server.state = TIME_WAIT;
                        ssn->client.state = LAST_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: LAST_ACK\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: TIME_WAIT\n"););
                        return ACTION_ACK_SERVER_DATA;
                    }
                    else if(p->tcph->th_flags == TH_FIN)
                    {
                        ssn->server.state = TIME_WAIT;
                        ssn->client.state = LAST_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: LAST_ACK\n");
                                DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: TIME_WAIT\n"););
                        return ACTION_ACK_SERVER_DATA;
                    }

                    return ACTION_NOTHING;

                case CLOSE_WAIT:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: CLOSE_WAIT\n"););

                    if(p->tcph->th_flags == TH_RST)
                    {
                        /* check window for evasive RSTs */
                        if(CheckRst(ssn, direction, pkt_seq, p))
                        {
                            ssn->server.state = CLOSED;
                            ssn->client.state = CLOSED;
                            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                        "   Client Transition: CLOSED\n");
                                    DebugMessage(DEBUG_STREAM,  
                                        "   Server Transition: CLOSED\n"););

                            return ACTION_FLUSH_CLIENT_STREAM | 
                                ACTION_FLUSH_SERVER_STREAM | 
                                ACTION_DROP_SESSION;
                        }
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->client.state = FIN_WAIT_2;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: FIN_WAIT_2\n"););
                        return ACTION_ACK_SERVER_DATA;
                    }


                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_2S:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Server state: "
                                "NMAP_FINGERPRINT_2S\n"););
                    if(p->tcph->th_flags == 0)
                    {
                        ssn->client.state = NMAP_FINGERPRINT_NULL;
                        ssn->server.state = NMAP_FINGERPRINT_NULL;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "nmap state transition: "
                                    "NMAP_FINGERPRINT_NULL\n"););
                        do_detect = 0;
                        return ACTION_INC_PORT;
                    }

                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_NULL:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Server state: "
                                "NMAP_FINGERPRINT_NULL\n"););
                    if(p->tcph->th_flags == (TH_URG|TH_PUSH|TH_SYN|TH_FIN))
                    {
                        ssn->client.state = NMAP_FINGERPRINT_UPSF;
                        ssn->server.state = NMAP_FINGERPRINT_UPSF;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "nmap state transition: "
                                    "NMAP_FINGERPRINT_UPSF\n"););
                        do_detect = 0;
                        return ACTION_INC_PORT;
                    }

                    return ACTION_NOTHING;

                case NMAP_FINGERPRINT_UPSF:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Server state: "
                                "NMAP_FINGERPRINT_UPSF\n"););
                    if(p->tcph->th_flags == TH_ACK)
                    {
                        ssn->client.state = NMAP_FINGERPRINT_ZERO_ACK;
                        ssn->server.state = NMAP_FINGERPRINT_ZERO_ACK;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "nmap state transition: "
                                    "NMAP_FINGERPRINT_ZERO_ACK\n"););
                        do_detect = 0;
                    }

                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "I should alert now!\n"););

                    return ACTION_ALERT_NMAP_FINGERPRINT;
            }
            return ACTION_NOTHING;
    }

    return ACTION_NOTHING;
}

/* int UpdateStateAsync(Session *ssn, Packet *p, u_int32_t pkt_seq)
 * 
 * Purpose: Do the state transition table for packets based solely on
 * one-sided converstations
 *
 * Returns:  which ACTIONS need to be taken on this state
 */
 
int UpdateStateAsync(Session *ssn, Packet *p, u_int32_t pkt_seq)
{
    int direction;

    direction = GetDirection(ssn, p);

    switch(direction)
    {
        case FROM_SERVER:  /* packet came from the server */
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                        "Client State: SYN_SENT\n"););

            ssn->server.pkts_sent++;
            ssn->server.bytes_sent += p->dsize;


            if(!(ssn->session_flags & SSNFLAG_SEEN_SERVER))
            {
                ssn->session_flags |= SSNFLAG_SEEN_SERVER;
            }

            switch(ssn->server.state)
            {
                case SYN_RCVD:
                    /* This is the first state the reassembler can stick in
                       in the Asynchronus state */

                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                "Server state: SYN_RCVD\n"););
                    if(p->tcph->th_flags & (TH_SYN|TH_ACK))
                    {
                        ssn->server.state = ESTABLISHED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: ESTABLISHED\n"););
                        return ACTION_COMPLETE_TWH;
                    }
                    return ACTION_NOTHING;

                case ESTABLISHED:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Server state: ESTABLISHED\n"););
                    if(p->tcph->th_flags & TH_FIN)
                    {
                        ssn->server.state = CLOSED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: FIN_WAIT_1\n"););

                        return ACTION_FLUSH_SERVER_STREAM | ACTION_DROP_SESSION;
                    }
                    else if(p->tcph->th_flags & TH_RST)
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                    "Got RST (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->server.state = CLOSED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Server Transition: CLOSED\n"););

                        return ACTION_FLUSH_SERVER_STREAM | ACTION_DROP_SESSION;
                    }

                    return ACTION_NOTHING;
            }

        case FROM_CLIENT:
            
            ssn->client.pkts_sent++;
            ssn->client.bytes_sent += p->dsize;

            if(!(ssn->session_flags & SSNFLAG_SEEN_CLIENT))
            {
                ssn->session_flags |= SSNFLAG_SEEN_CLIENT;
            }

            switch(ssn->client.state)
            {
                case SYN_SENT:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Client State: SYN_SENT\n"););
                    if(p->tcph->th_flags & TH_RST)
                    {
                        ssn->client.state = CLOSED;

                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSED -- RESET\n"););

                        return ACTION_FLUSH_CLIENT_STREAM | ACTION_DROP_SESSION;
                    }
                    else if(p->tcph->th_flags & TH_ACK)
                    {
                        ssn->client.state = ESTABLISHED;

                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: ESTABLISHED\n"););

                        return ACTION_NOTHING;
                    }


                    return ACTION_NOTHING;


                case ESTABLISHED:
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Client state: ESTABLISHED\n"););

                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                "Session State: ESTABLISHED\n"););
                    ssn->session_flags |= SSNFLAG_ESTABLISHED;


                    if(p->tcph->th_flags & TH_FIN)
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                    "Got FIN (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->client.state = CLOSED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: CLOSEd\n"););

                        return ACTION_FLUSH_CLIENT_STREAM | ACTION_DROP_SESSION;
                    }
                    else if(p->tcph->th_flags & TH_RST)
                    {
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                    "Got RST (0x%X)\n", 
                                    p->tcph->th_flags););
                        ssn->client.state = CLOSED;
                        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  
                                    "   Client Transition: Closed\n"););

                        return ACTION_FLUSH_CLIENT_STREAM | ACTION_DROP_SESSION;
                    }
                    break;
            }
    }

    return ACTION_NOTHING;
}



Session *CreateNewSession(Packet *p, u_int32_t pkt_seq, u_int32_t pkt_ack)
{
    Session *idx = NULL;
    Event event;
    static u_int8_t savedfpi; /* current flush point index */
    u_int8_t fpi;            /* flush point index */
    int insert = 1;
    int alert = 0;
    char alert_msg[STD_BUF];


    /* assign a psuedo random flush point */
    savedfpi++;
    fpi = savedfpi % FCOUNT;    
    
    switch(p->tcph->th_flags)
    {
    case TH_RES1|TH_RES2|TH_SYN: /* possible ECN traffic */
        if(p->iph->ip_tos == 0x02)
        {
            /* it is ECN traffic */
            p->packet_flags |= PKT_ECN;
        }
                
        /* fall through */

    case TH_SYN:  /* setup session on first packet of TWH */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] initializing new session "
                                "(%d bytes)\n", sizeof(Session)););

        idx = (Session *) SafeAlloc(sizeof(Session), p->pkth->ts.tv_sec,
                                    NULL);

        idx->server.dataPtr = &idx->server.data;
        idx->client.dataPtr = &idx->client.data;

        (void)ubi_trInitTree(idx->server.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        (void)ubi_trInitTree(idx->client.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        idx->server.state = LISTEN;        
        idx->server.ip = p->iph->ip_dst.s_addr;
        idx->server.port = p->dp;

        idx->client.state = SYN_SENT;
        idx->client.ip = p->iph->ip_src.s_addr;
        idx->client.port = p->sp;
        idx->client.isn = pkt_seq;
        idx->server.win_size = ntohs(p->tcph->th_win);

        idx->start_time = p->pkth->ts.tv_sec;
        idx->last_session_time = p->pkth->ts.tv_sec;

        idx->session_flags |= SSNFLAG_SEEN_CLIENT;

        if(p->packet_flags & PKT_ECN)
        {
            idx->session_flags |= SSNFLAG_ECN_CLIENT_QUERY;
        }

        idx->flush_point = flush_points[fpi];
        break;

    case TH_RES2|TH_SYN|TH_ACK:
        if(p->iph->ip_tos == 0x02)
        {
            p->packet_flags |= PKT_ECN;
        }

        /* fall through */

    case TH_SYN|TH_ACK: /* maybe we missed the SYN packet... */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] initializing new session "
                                "(%d bytes)\n", sizeof(Session)););

        idx = (Session *) SafeAlloc(sizeof(Session), p->pkth->ts.tv_sec, 
                                    NULL);

        idx->server.dataPtr = &idx->server.data;
        idx->client.dataPtr = &idx->client.data;

        (void)ubi_trInitTree(idx->server.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        (void)ubi_trInitTree(idx->client.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        idx->server.state = SYN_RCVD;
        idx->client.state = SYN_SENT;

        idx->server.ip = p->iph->ip_src.s_addr;
        idx->server.port = p->sp;
        idx->server.isn = pkt_seq;
        idx->client.win_size = ntohs(p->tcph->th_win);

        idx->client.ip = p->iph->ip_dst.s_addr;
        idx->client.port = p->dp;
        idx->client.isn = pkt_ack-1;

        idx->start_time = p->pkth->ts.tv_sec;
        idx->last_session_time = p->pkth->ts.tv_sec;
        idx->session_flags = SSNFLAG_SEEN_SERVER;
        idx->flush_point = flush_points[fpi];
        break;

    case TH_ACK: 
    case TH_ACK|TH_PUSH: 
    case TH_FIN|TH_ACK:
    case TH_RST|TH_ACK:
    case TH_ACK|TH_URG:
    case TH_ACK|TH_PUSH|TH_URG:
    case TH_FIN|TH_ACK|TH_URG:
    case TH_ACK|TH_PUSH|TH_FIN:
    case TH_ACK|TH_PUSH|TH_FIN|TH_URG:
        /* 
         * missed the TWH or just got the last packet of the 
         * TWH, or we're catching this session in the middle
         */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] initializing new session "
                                "(%d bytes)\n", sizeof(Session)););

        idx = (Session *) SafeAlloc(sizeof(Session), p->pkth->ts.tv_sec,
                                    NULL);

        idx->server.dataPtr = &idx->server.data;
        idx->client.dataPtr = &idx->client.data;

        (void)ubi_trInitTree(idx->server.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        (void)ubi_trInitTree(idx->client.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        idx->server.state = ESTABLISHED;
        idx->client.state = ESTABLISHED;

        idx->server.ip = p->iph->ip_dst.s_addr;
        idx->server.port = p->dp;
        idx->server.isn = pkt_ack-1;
        idx->server.last_ack = pkt_ack;
        idx->server.base_seq = idx->server.last_ack;

        idx->client.ip = p->iph->ip_src.s_addr;
        idx->client.port = p->sp;
        idx->client.isn = pkt_seq-1;
        idx->client.last_ack = pkt_seq;
        idx->client.base_seq = idx->client.last_ack;
        idx->server.win_size = ntohs(p->tcph->th_win);

        idx->start_time = p->pkth->ts.tv_sec;
        idx->last_session_time = p->pkth->ts.tv_sec;
        idx->session_flags = SSNFLAG_SEEN_CLIENT;
        idx->flush_point = flush_points[fpi];
        break;

    case TH_RES2|TH_SYN: /* nmap fingerprint packet */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] initializing new session "
                                "(%d bytes)\n", sizeof(Session));
                   DebugMessage(DEBUG_STREAM,
                       "nmap fingerprint scan 2SYN packet!\n"););
        idx = (Session *) SafeAlloc(sizeof(Session), p->pkth->ts.tv_sec, NULL);

        idx->server.dataPtr = &idx->server.data;
        idx->client.dataPtr = &idx->client.data;

        (void)ubi_trInitTree(idx->server.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        (void)ubi_trInitTree(idx->client.dataPtr, /* ptr to the tree head */
                             DataCompareFunc, /* comparison function */
                             0);              /* don't allow overwrites */

        idx->server.state = NMAP_FINGERPRINT_2S;
        idx->client.state = NMAP_FINGERPRINT_2S;

        idx->server.ip = p->iph->ip_dst.s_addr;
        idx->server.port = p->dp;

        idx->client.ip = p->iph->ip_src.s_addr;
        idx->client.port = p->sp; /* cp incs by one for each packet */
        idx->client.port++;
        idx->client.isn = pkt_seq;
        idx->server.win_size = ntohs(p->tcph->th_win);

        idx->start_time = p->pkth->ts.tv_sec;
        idx->last_session_time = p->pkth->ts.tv_sec;

        idx->session_flags = SSNFLAG_SEEN_CLIENT|SSNFLAG_NMAP;
        idx->flush_point = flush_points[fpi];
    
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"init nmap for sip: 0x%X sp: %d  "
                                "cip: 0x%X cp: %d\n", 
                                idx->server.ip, idx->server.port, 
                                idx->client.ip, idx->client.port););

        do_detect = 0;
        break;


    case TH_SYN|TH_RST|TH_ACK|TH_FIN|TH_PUSH|TH_URG:
        if(s4data.ps_alerts)
        {
            /* Full XMAS scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_FULL_XMAS, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_FULL_XMAS_STR , STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    case TH_SYN|TH_ACK|TH_URG|TH_PUSH:
        if(s4data.ps_alerts)
        {
            /* SAPU scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_SAPU, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_SAPU_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    case TH_FIN:
        if(s4data.ps_alerts)
        {
            /* possible FIN scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_FIN_SCAN, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_FIN_SCAN_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    case TH_SYN|TH_FIN:
        if(s4data.ps_alerts)
        {
            /* SYN FIN scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_SYN_FIN_SCAN, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_SYN_FIN_SCAN_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;


    case 0:
        if(s4data.ps_alerts)
        {
            /* NULL scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_NULL_SCAN, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_NULL_SCAN_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    case TH_FIN|TH_PUSH|TH_URG:
        if(s4data.ps_alerts)
        {
            /* nmap XMAS scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_NMAP_XMAS_SCAN, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_NMAP_XMAS_SCAN_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    case TH_URG:
    case TH_PUSH:
    case TH_FIN|TH_URG:
    case TH_PUSH|TH_FIN:
    case TH_URG|TH_PUSH:
        if(s4data.ps_alerts)
        {
            /* vecna scan */
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_VECNA_SCAN, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_VECNA_SCAN_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }
        insert = 0;
        break;

    default: /* 
              * some kind of non-kosher activity occurred, drop the node 
              * and flag a portscan
              */
        if(s4data.ps_alerts)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_ACTIVITY, 1, 0, 5, 0);
            strlcpy(alert_msg, STREAM4_STEALTH_ACTIVITY_STR, STD_BUF);
            alert = 1;
            do_detect = 0;
        }

        insert = 0;

        return NULL;
    }

    if(alert && s4data.ps_alerts)
    {
        /*  PortscanDeclare(p); */
        CallAlertFuncs(p, alert_msg, NULL, &event);
        CallLogFuncs(p, alert_msg, NULL, &event);
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                "returning due to portscan alert!"););
        return NULL;
    }

    if(insert)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                    "Inserting session into session tree...\n"););
        
        if(ubi_sptInsert(RootPtr,(ubi_btNodePtr)idx,(ubi_btNodePtr)idx, NULL)
           == FALSE)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                        "sptInsert failed, that's going to "
                                    "make life difficult\n"););
            
            stream4_memory_usage -= sizeof(Session);
            free(idx);
            return NULL;
        }

        pc.tcp_streams++;
    }

    return idx;
}



void DeleteSession(Session *ssn, u_int32_t time)
{
    struct in_addr foo;
    register int s;
    struct tm *lt;
    struct tm *et;
    Session *killme;
    long currentTime;

    sfPerf.sfBase.DeletedSessions++;
    sfPerf.sfBase.TotalSessions--;

    
    if(ssn == NULL)
        return;

    if(s4data.track_stats_flag == STATS_HUMAN_READABLE)
    {
        lt = localtime((time_t *) &ssn->start_time);
        s = (ssn->start_time + thiszone) % 86400;

        fprintf(session_log, "[*] Session stats:\n   Start Time: ");
        fprintf(session_log, "%02d/%02d/%02d-%02d:%02d:%02d", lt->tm_mon+1,
                lt->tm_mday, lt->tm_year - 100, s/3600, (s%3600)/60, s%60);

        et = localtime((time_t *) &ssn->last_session_time);
        s = (ssn->last_session_time + thiszone) % 86400;
        fprintf(session_log, "   End Time: %02d/%02d/%02d-%02d:%02d:%02d\n", 
                et->tm_mon+1, et->tm_mday, et->tm_year - 100, s/3600, 
                (s%3600)/60, s%60);

        foo.s_addr = ssn->server.ip;
        fprintf(session_log, "   Server IP: %s  ", inet_ntoa(foo));
        fprintf(session_log, "port: %d  pkts: %u  bytes: %u\n", 
                ssn->server.port, ssn->server.pkts_sent, 
                ssn->server.bytes_sent);
        foo.s_addr = ssn->client.ip;
        fprintf(session_log, "   Client IP: %s  ", inet_ntoa(foo));
        fprintf(session_log, "port: %d  pkts: %u  bytes: %u\n", 
                ssn->client.port, ssn->client.pkts_sent, 
                ssn->client.bytes_sent);

    }
    else if(s4data.track_stats_flag == STATS_MACHINE_READABLE)
    {
        lt = localtime((time_t *) &ssn->start_time);
        s = (ssn->start_time + thiszone) % 86400;

        fprintf(session_log, "[*] Session => Start: ");
        fprintf(session_log, "%02d/%02d/%02d-%02d:%02d:%02d", lt->tm_mon+1,
                lt->tm_mday, lt->tm_year - 100, s/3600, (s%3600)/60, s%60);

        et = localtime((time_t *) &ssn->last_session_time);
        s = (ssn->last_session_time + thiszone) % 86400;
        fprintf(session_log, " End Time: %02d/%02d/%02d-%02d:%02d:%02d", 
                et->tm_mon+1, et->tm_mday, et->tm_year - 100, s/3600, 
                (s%3600)/60, s%60);

        foo.s_addr = ssn->server.ip;
        fprintf(session_log, "[Server IP: %s  ", inet_ntoa(foo));
        fprintf(session_log, "port: %d  pkts: %u  bytes: %u]", 
                ssn->server.port, ssn->server.pkts_sent, 
                ssn->server.bytes_sent);
        foo.s_addr = ssn->client.ip;
        fprintf(session_log, " [Client IP: %s  ", inet_ntoa(foo));
        fprintf(session_log, "port: %d  pkts: %u  bytes: %u]\n", 
                ssn->client.port, ssn->client.pkts_sent, 
                ssn->client.bytes_sent);
    }
    else if(s4data.track_stats_flag == STATS_DB)
    {
       dbsPtr = AddDbStats(dbsPtr, ssn);
       currentTime = TimeMilliseconds();
       if (currentTime > (LastFlushTime + FLUSH_DELAY)) 
         dbsPtr = FlushDbStats(dbsPtr);
    }
    else if(s4data.track_stats_flag == STATS_BINARY)
    {
        BinStats bs;  /* lets generate some BS */

        bs.start_time = ssn->start_time;
        bs.end_time = ssn->last_session_time;
        bs.sip = ssn->server.ip;
        bs.cip = ssn->client.ip;
        bs.sport = ssn->server.port;
        bs.cport = ssn->client.port;
        bs.spackets = ssn->server.pkts_sent;
        bs.cpackets = ssn->client.pkts_sent;
        bs.sbytes = ssn->server.bytes_sent;
        bs.cbytes = ssn->client.bytes_sent;

        WriteSsnStats(&bs);
    }

    if(ubi_trCount(RootPtr))
    {
        killme = (Session *) ubi_sptRemove(RootPtr, (ubi_btNodePtr) ssn);

        DropSession(killme);
    }
}



int CheckRst(Session *ssn, int direction, u_int32_t pkt_seq, Packet *p)
{
    Stream *s;
    Event event;

    if(direction == FROM_SERVER)
    {
        s = &ssn->server;
    }
    else
    {
        s = &ssn->client;
    }

    if((s->last_ack > 0)           &&
       (pkt_seq < s->last_ack   || 
        pkt_seq >= (s->last_ack+s->win_size)))
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Bad RST packet, no cookie!\n");
                   DebugMessage(DEBUG_STREAM, "pkt seq: 0x%X   last_ack: 0x%X   "
                                "win: 0x%X\n", pkt_seq, s->last_ack, s->win_size););

        /* we should probably alert here */
        if(s4data.evasion_alerts)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_EVASIVE_RST, 1, 0, 5, 0);
            CallAlertFuncs(p, STREAM4_EVASIVE_RST_STR, NULL, &event);
            CallLogFuncs(p, STREAM4_EVASIVE_RST_STR, NULL, &event);
        }

        return 0;
    }

    return 1;
}


void DropSession(Session *ssn)
{
    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,  "Dropping session %p\n", ssn););

    if(ssn == NULL)
        return;

    DeleteSpd((ubi_trRootPtr)ssn->server.dataPtr, 0);

    DeleteSpd((ubi_trRootPtr)ssn->client.dataPtr, 0);

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[F] Freeing %d byte session\n", 
                            sizeof(Session)););
    
    stream4_memory_usage -= sizeof(Session);
    free(ssn);
}

void DeleteSpd(ubi_trRootPtr Root, int log)
{
    (void)ubi_trKillTree(Root, KillSpd);
}


int GetDirection(Session *ssn, Packet *p)
{
    if(p->tcph->th_flags == TH_SYN)
    {
        ssn->client.port = p->sp;
        ssn->server.port = p->dp;
        return FROM_CLIENT;
    }
    else if(p->sp == ssn->client.port)
    {
        return FROM_CLIENT;
    }
        
    return FROM_SERVER;
}


Session *GetSession(Packet *p)
{
    Session idx;
    Session *returned;
#ifdef DEBUG
    char flagbuf[9];
    CreateTCPFlagString(p, flagbuf);
#endif

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Trying to get session...\n"););
    idx.server.ip = p->iph->ip_src.s_addr;
    idx.client.ip = p->iph->ip_dst.s_addr;
    idx.server.port = p->sp;
    idx.client.port = p->dp;

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Looking for sip: 0x%X sp: %d  cip: 0x%X cp: %d "
                            "flags: %s\n", idx.server.ip, idx.server.port, idx.client.ip, 
                            idx.client.port, flagbuf););

    returned = (Session *) ubi_sptFind(RootPtr, (ubi_btItemPtr)&idx);

    if(returned == NULL)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "GetSession forward didn't work, trying "
                                "backwards...\n"););
        idx.server.ip = p->iph->ip_dst.s_addr;
        idx.client.ip = p->iph->ip_src.s_addr;
        idx.server.port = p->dp;
        idx.client.port = p->sp;
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Looking for sip: 0x%X sp: %d  "
                                "cip: 0x%X cp: %d flags: %s\n", idx.server.ip, 
                                idx.server.port, idx.client.ip, idx.client.port,
                                flagbuf););
        returned = (Session *) ubi_sptFind(RootPtr, (ubi_btItemPtr)&idx);
    }

    if(returned == NULL)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Unable to find session\n"););
    }
    else
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Found session\n"););
    }

    return returned;
}

void Stream4CleanExitFunction(int signal, void *foo)
{
    if(s4data.track_stats_flag)
    {
        if(s4data.track_stats_flag != STATS_BINARY)
        {
          if(s4data.track_stats_flag == STATS_DB)
          {
            dbsPtr = FlushDbStats(dbsPtr);
          } else {
            fclose(session_log);
          }
    }
        else
            if(stats_log != NULL)
                fclose(stats_log->fp);
    }
}

void Stream4RestartFunction(int signal, void *foo)
{
    if(s4data.track_stats_flag)
    {
        if(s4data.track_stats_flag != STATS_BINARY)
            fclose(session_log);
        else
            if(stats_log != NULL)
                fclose(stats_log->fp);
    }
}

void PrintSessionCache()
{
    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "%lu streams active, %u bytes in use\n", 
                            ubi_trCount(RootPtr), stream4_memory_usage););

    return;
}

int PruneSessionCache(u_int32_t thetime, int mustdie, Session *save_me)
{
    Session *idx;
    u_int32_t pruned = 0;

    if(ubi_trCount(RootPtr) == 0)
    {
        return 0;
    }
    
    if(!mustdie)
    {
        idx = (Session *) ubi_btFirst((ubi_btNodePtr)RootPtr->root);

        if(idx == NULL)
        {
            return 0;
        }

        do
        {
            if(idx == save_me)
            {
                idx = (Session *) ubi_btNext((ubi_btNodePtr)idx);
                continue;
            }

            if((idx->last_session_time+s4data.timeout) < thetime)
            {
                Session *savidx = idx;

                if(ubi_trCount(RootPtr) > 1)
                {
                    idx = (Session *) ubi_btNext((ubi_btNodePtr)idx);
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "pruning stale session\n"););
                    DeleteSession(savidx, thetime);
                    pruned++;
                }
                else
                {
                    DeleteSession(savidx, thetime);
                    pruned++;
                    return pruned;
                }
            }
            else
            {
                if(idx != NULL && ubi_trCount(RootPtr))
                {
                    idx = (Session *) ubi_btNext((ubi_btNodePtr)idx);
                }
                else
                {
                    return pruned;
                }
            }
        } while(idx != NULL);

        return pruned;
    }
    else
    {
        while(mustdie-- &&  ubi_trCount(RootPtr) > 1)
        {
            idx = (Session *) ubi_btLeafNode((ubi_btNodePtr)RootPtr);
            if(idx != save_me)
                DeleteSession(idx, thetime);
        }
#ifdef DEBUG
        if(mustdie) {
            DebugMessage(DEBUG_STREAM, "Emptied out the stream cache"
                         "completely mustdie: %d, memusage: %u\n",
                         mustdie,
                         stream4_memory_usage);
        }
#endif /* DEBUG */

        return 0;
    }

    return 0;
}


void StoreStreamPkt(Session *ssn, Packet *p, u_int32_t pkt_seq)
{
    Stream *s;
    StreamPacketData *spd;
    StreamPacketData *returned;
    StreamPacketData *foo;
    Event event;

    int direction = GetDirection(ssn, p);

    /* select the right stream */
    if(direction == FROM_CLIENT)
    {
        if(!s4data.reassemble_client)
        {
            return;
        }

        s = &ssn->client;

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Storing client packet (%d bytes)\n", 
                                p->pkth->caplen););

        /* Go ahead and detect ttl attacks if we already have one
           ttl from the stream

           since fragroute does this a lot, perhaps we should have a
           counter to avoid false positives.. -- cmg
        */

        if(s4data.ttl_limit)
        {
            if(ssn->ttl && p->iph->ip_ttl < 10)
            { /* have we already set a client ttl? */
                if(abs(ssn->ttl - p->iph->ip_ttl) >= s4data.ttl_limit) {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_TTL_EVASION, 1, 0, 5, 0);
                    CallAlertFuncs(p, STREAM4_TTL_EVASION_STR, NULL, &event);
                    CallLogFuncs(p, STREAM4_TTL_EVASION_STR, NULL, &event);
                    /* throw away this stuff so we
                       will still see the real attack */
                    return;

                }
            } else {
                ssn->ttl = p->iph->ip_ttl; /* first packet we've seen,
                                              lets go ahead and set it. */

            }

        }
    }
    else
    {
        if(!s4data.reassemble_server)
        {
            return;
        }

        s = &ssn->server;

        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Storing server packet (%d bytes)\n", 
                                p->pkth->caplen););
    }

    /* check for retransmissions of data that's already been ack'd */
    if((pkt_seq < s->last_ack) && (s->last_ack > 0) && 
       (direction == FROM_CLIENT))
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"EVASIVE RETRANS: pkt seq: 0x%X "
                                "stream->last_ack: 0x%X\n", pkt_seq, s->last_ack););

        if(s4data.state_alerts)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_EVASIVE_RETRANS, 1, 0, 5, 0);
            CallAlertFuncs(p, STREAM4_EVASIVE_RETRANS_STR, NULL, &event);
            CallLogFuncs(p, STREAM4_EVASIVE_RETRANS_STR, NULL, &event);
        }

        return;
    }

    /* check for people trying to write outside the window */
    if(((pkt_seq + p->dsize - s->last_ack) > s->win_size) && 
       (s->win_size > 0) && direction == FROM_CLIENT)
    {
        /*
         * got data out of the window, someone is FUCKING around or you've got
         * a really crappy IP stack implementaion (hello microsoft!)
         */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WINDOW VIOLATION: seq: 0x%X  "
                                "last_ack: 0x%X  dsize: %d  " "window: 0x%X\n", 
                                pkt_seq, s->last_ack, p->dsize, s->win_size););

        if(s4data.state_alerts)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_WINDOW_VIOLATION, 1, 0, 5, 0);
            CallAlertFuncs(p, STREAM4_WINDOW_VIOLATION_STR, NULL, &event);
            CallLogFuncs(p, STREAM4_WINDOW_VIOLATION_STR, NULL, &event);
        }

        return;
    }

    /* prepare a place to put the data */
    if(s->state >= ESTABLISHED)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] Allocating %d bytes for "
                                "StreamPacketData\n", sizeof(StreamPacketData)););

        spd = (StreamPacketData *) SafeAlloc(sizeof(StreamPacketData), 
                                             p->pkth->ts.tv_sec, ssn);

        spd->seq_num = pkt_seq;
        spd->payload_size = p->dsize;
        spd->cksum = p->tcph->th_sum;

        /* attach the packet here */
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "[A] Allocating %u bytes for packet\n", 
                                p->pkth->caplen););

        spd->pkt = (u_int8_t *) SafeAlloc(p->pkth->caplen, p->pkth->ts.tv_sec, 
                                          ssn);
        spd->pkt_size = p->pkth->caplen;

        /* copy the packet */
        memcpy(spd->pkt, p->pkt, p->pkth->caplen);

        /* copy the packet header */
        memcpy(&spd->pkth, p->pkth, sizeof(SnortPktHeader));

        /* set the pointer to the stored packet payload */
        spd->payload = spd->pkt + (p->data - p->pkt);
    }
    else
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: Data on unestablished session "
                                "(state: %d)!\n", s->state););
        return;
    }


    /* check for retransmissions */
    returned = (StreamPacketData *) ubi_sptFind(s->dataPtr, (ubi_btItemPtr)spd);

    if(returned != NULL)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: returned packet not null\n"););
        if(returned->payload_size == p->dsize)
        {
            /* check to see if the data has been ack'd */
            if(s->last_ack < pkt_seq + p->dsize)
            {
                /* retransmission of un-ack'd packet, chuck the old one 
                 * and put in the new one
                 * --------------------------------------------------
                 * We have to be aware of two packets sent one right
                 * after the other
                 *
                 * One packet sends us the data they want the remote
                 * host to recieve, the next sends us the data they
                 * want the IDS to incorrectly pick up.
                 *
                 * This gets us into the *nasty* problem of how to
                 * detect differing data.
                 *
                 * Hopefully this doesn't occur too much in real life
                 * because this check will make life slow in the
                 * normal case.  Of course it will just be an extra
                 * check on port 80 check for pattern matching which
                 * already hurts us enough as is :-)
                 *
                 */

                DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                        "Checking Packet Contents versus Packet Store\n"););

                if(returned->cksum != p->tcph->th_sum)
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "TCP Checksums not equal\n"););

    
                    stream4_memory_usage -= spd->pkt_size;
                    free(spd->pkt);
    
                    stream4_memory_usage -= sizeof(StreamPacketData);
                    free(spd);

                    if(s4data.evasion_alerts)
                    {
                        SetEvent(&event, GENERATOR_SPP_STREAM4, 
                                 STREAM4_EVASIVE_RETRANS_DATA, 1, 0, 5, 0);

                        CallAlertFuncs(p, STREAM4_EVASIVE_RETRANS_DATA_STR, 
                                       NULL, &event);

                        CallLogFuncs(p, STREAM4_EVASIVE_RETRANS_DATA_STR,
                                     NULL, &event);
                    }
    
                    return;
                } else {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                            "TCP Checksums equal..."
                                            " returning; see comment in src\n"););
                    /*  Possible Research chance:

                    How easy is it to fool IDSes by retransmissions
                    with the same checksum but different IPs...
                    */
                    stream4_memory_usage -= spd->pkt_size;
                    free(spd->pkt);
    
                    stream4_memory_usage -= sizeof(StreamPacketData);
                    free(spd);

                    return;
                }
            }
            else
            {
                /* screw it, we already ack'd this data */
                stream4_memory_usage -= spd->pkt_size;
                free(spd->pkt);

                stream4_memory_usage -= sizeof(StreamPacketData);
                free(spd);

                if(s4data.state_alerts)
                {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_EVASIVE_RETRANS, 1, 0, 5, 0);
                    CallAlertFuncs(p, STREAM4_EVASIVE_RETRANS_STR,
                                   NULL, &event);
                    CallLogFuncs(p, STREAM4_EVASIVE_RETRANS_STR, NULL, &event);
                }
                return;
            }
        }
        else if(returned->payload_size < p->dsize)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                    "Duplicate packet with forward overlap\n"););

            /* check to see if this one's been ack'd */
            if(s->last_ack > pkt_seq + p->dsize)
            {
                /* screw it, we already ack'd this data */
                stream4_memory_usage -= spd->pkt_size;
                free(spd->pkt);

                stream4_memory_usage -= sizeof(StreamPacketData);
                free(spd);

                if(s4data.evasion_alerts)
                {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_FORWARD_OVERLAP, 0, 5, 0, 0);
                    CallAlertFuncs(p, STREAM4_FORWARD_OVERLAP_STR,
                                   NULL, &event);
                    CallLogFuncs(p, STREAM4_FORWARD_OVERLAP_STR, NULL, &event);
                }

                return;
            }
            else
            {
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                        "Replacing un-ack'd segment in Packet Store\n"););

                foo = (StreamPacketData *) ubi_sptRemove(s->dataPtr, 
                                                         (ubi_btNodePtr) returned);

                stream4_memory_usage -= foo->pkt_size;
                free(foo->pkt);

                stream4_memory_usage -= sizeof(StreamPacketData);
                free(foo);
            }
        }
        else if(returned->payload_size > p->dsize)
        {
            /* check to see if this one's been ack'd */
            if(s->last_ack > pkt_seq + p->dsize)
            {
                /* screw it, we already ack'd this data */
                stream4_memory_usage -= spd->pkt_size;
                free(spd->pkt);

                stream4_memory_usage -= sizeof(StreamPacketData);
                free(spd);

                if(s4data.state_alerts)
                {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_EVASIVE_RETRANS, 1, 0, 5, 0);
                    CallAlertFuncs(p, STREAM4_EVASIVE_RETRANS_STR,
                                   NULL, &event);
                    CallLogFuncs(p, STREAM4_EVASIVE_RETRANS_STR, NULL, &event);
                }
                return;
            }
            else
            {
                /* Some tool will probably have the following scenario one day.
                   send a bunch of 1 byte packets that the remote host should see and
                   start acking and then follow that up with one big packet

                   To defeat this, we have to see if the contents of
                   the big packet match up with the ton of dinky packets...

                   Instead of just going to look for every damn one of
                   the packets, lets just compare the timestamp of our
                   current packet versus the retransmitted one.

                   We could probably detect all the fun retransmission
                   games this way.
                */
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                        "Checking if we are retranmitting too fast\n"););

                if(RetransTooFast(&returned->pkth.ts,  (struct timeval *) &p->pkth->ts))
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                            "Generating packets retranmissions faster than we should\n"););
        
                    stream4_memory_usage -= spd->pkt_size;
                    free(spd->pkt);
    
                    stream4_memory_usage -= sizeof(StreamPacketData);
                    free(spd);

                    if(s4data.evasion_alerts)
                    {
                        SetEvent(&event, GENERATOR_SPP_STREAM4, 
                                 STREAM4_EVASIVE_RETRANS_DATASPLIT, 1, 0, 5, 0);
                        
                        CallAlertFuncs(p, STREAM4_EVASIVE_RETRANS_DATASPLIT_STR,
                                       NULL, &event);
                        
                        CallLogFuncs(p, STREAM4_EVASIVE_RETRANS_DATASPLIT_STR,
                                     NULL, &event);
                    }
                    return;
                } else {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                                            "Replacing un-ack'd segment in Packet Store\n"););
    
                    foo = (StreamPacketData *) ubi_sptRemove(s->dataPtr, 
                                                             (ubi_btNodePtr) returned);
    
                    stream4_memory_usage -= foo->pkt_size;
                    free(foo->pkt);
    
                    stream4_memory_usage -= sizeof(StreamPacketData);
                    free(foo);
                }

            }
        }
    }

    if(ubi_sptInsert(s->dataPtr,(ubi_btNodePtr)spd,(ubi_btNodePtr)spd, NULL)
       == FALSE)
    {
        LogMessage("sptInsert failed, that sucks\n");
        return;
    }

    p->packet_flags |= PKT_STREAM_INSERT;

    return;
}



void FlushStream(Stream *s, Packet *p, int direction)
{
    u_int32_t stream_size;
    int gotevent = 0;

    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "FlushStream Entered:"
                            "last_ack(%u) base_seq(%u) trCount(%u)\ng",
                            s->last_ack, s->base_seq, ubi_trCount(s->dataPtr)););
    if(s->last_ack == 0 || 
       s->base_seq == 0 || 
       (s->last_ack < s->base_seq) ||
       (s->last_ack - s->base_seq > 65535))
    {
        /* yeah, I know this is lame, we'll fix it */
        DeleteSpd(s->dataPtr, gotevent);
        return;
    }

    stream_size = s->last_ack - s->base_seq;
    
    if(stream_size > 0 && ubi_trCount(s->dataPtr))
    {
        /* put the stream together into a packet or something */
        BuildPacket(s, stream_size, p, direction);

        gotevent = Preprocess(stream_pkt);

        if(gotevent)
        {
            LogStream(s);
        }
        
        //(void)ubi_trTraverse(s->dataPtr, SegmentCleanTraverse, s);
        SegmentCleanTraverse(s);
        /*bzero(stream_pkt->data, stream_size);*/

        return;
    }
    else
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM,"Passing large packet on 0 size stream cache\n"););
    }

    DeleteSpd(s->dataPtr, gotevent);
}


int AlertFlushStream(Packet *p, void *session)
{
    Session *ssn = (Session *)session;
    int nodecount = 0;

    if(ssn != NULL)
    {
        if(GetDirection(ssn, p) == FROM_SERVER)
        {
            nodecount = LogStream(&ssn->server);

            DeleteSpd(ssn->server.dataPtr, 1);
        }
        else
        {
            nodecount = LogStream(&ssn->client);

            DeleteSpd(ssn->client.dataPtr, 1);
        }
    }

    return nodecount;
}


int LogStream(Stream *s)
{
    int nodecount = 0;
    
    if(pv.log_bitmap & LOG_TCPDUMP && s4data.log_flushed_streams)
    {
        nodecount = ubi_trCount(s->dataPtr);
        (void)ubi_trTraverse(s->dataPtr, LogTraverse, s);
    }

    return nodecount;
}



void InitStream4Pkt()
{
    stream_pkt->pkth = calloc(sizeof(SnortPktHeader)+
                              ETHERNET_HEADER_LEN +
                              SPARC_TWIDDLE +
                              65536, sizeof(char));

    stream_pkt->pkt = ((u_int8_t *)stream_pkt->pkth) + sizeof(SnortPktHeader);
    stream_pkt->eh = (EtherHdr *)((u_int8_t *)stream_pkt->pkt + SPARC_TWIDDLE);
    stream_pkt->iph =
        (IPHdr *)((u_int8_t *)stream_pkt->eh + ETHERNET_HEADER_LEN);
    stream_pkt->tcph = (TCPHdr *)((u_int8_t *)stream_pkt->iph + IP_HEADER_LEN);

    stream_pkt->data = (u_int8_t *)stream_pkt->tcph + TCP_HEADER_LEN;

    stream_pkt->eh->ether_type = htons(0x0800);
    SET_IP_VER(stream_pkt->iph, 0x4);
    SET_IP_HLEN(stream_pkt->iph, 0x5);
    stream_pkt->iph->ip_proto = IPPROTO_TCP;
    stream_pkt->iph->ip_ttl   = 0xF0;
    stream_pkt->iph->ip_len = 0x5;
    stream_pkt->iph->ip_tos = 0x10;

    SET_TCP_OFFSET(stream_pkt->tcph,0x5);
    stream_pkt->tcph->th_flags = TH_PUSH|TH_ACK;
}



void BuildPacket(Stream *s, u_int32_t stream_size, Packet *p, int direction)
{
    BuildData bd;
    Session *ssn;
    
    stream_pkt->pkth->ts.tv_sec = p->pkth->ts.tv_sec;
    stream_pkt->pkth->ts.tv_usec = p->pkth->ts.tv_usec;

    stream_pkt->pkth->caplen = ETHERNET_HEADER_LEN + IP_HEADER_LEN + 
        TCP_HEADER_LEN + stream_size;
    stream_pkt->pkth->len = stream_pkt->pkth->caplen;

    stream_pkt->iph->ip_len = htons( (u_short) (IP_HEADER_LEN + 
                                                TCP_HEADER_LEN + stream_size) );

    if(direction == REVERSE)
    {
        if(p->eh != NULL)
        {
            memcpy(stream_pkt->eh->ether_dst, p->eh->ether_src, 6);
            memcpy(stream_pkt->eh->ether_src, p->eh->ether_dst, 6);
        }

        stream_pkt->tcph->th_sport = p->tcph->th_dport;
        stream_pkt->tcph->th_dport = p->tcph->th_sport;
        stream_pkt->iph->ip_src.s_addr = p->iph->ip_dst.s_addr;
        stream_pkt->iph->ip_dst.s_addr = p->iph->ip_src.s_addr;
        stream_pkt->sp = p->dp;
        stream_pkt->dp = p->sp;
    }
    else
    {
        if(p->eh != NULL)
        {
            memcpy(stream_pkt->eh->ether_dst, p->eh->ether_dst, 6);
            memcpy(stream_pkt->eh->ether_src, p->eh->ether_src, 6);
        }

        stream_pkt->tcph->th_sport = p->tcph->th_sport;
        stream_pkt->tcph->th_dport = p->tcph->th_dport;
        stream_pkt->iph->ip_src.s_addr = p->iph->ip_src.s_addr;
        stream_pkt->iph->ip_dst.s_addr = p->iph->ip_dst.s_addr;
        stream_pkt->sp = p->sp;
        stream_pkt->dp = p->dp;
    }

    stream_pkt->tcph->th_seq = p->tcph->th_seq;
    stream_pkt->tcph->th_ack = p->tcph->th_ack;
    stream_pkt->tcph->th_win = p->tcph->th_win;

    if(stream_size > 65500)
    {
        stream_pkt->dsize = 0;
        return;
    }

    s4data.stop_traverse = 0;
    
    bd.stream = s;
    bd.buf = stream_pkt->data;
    bd.total_size = 0;

    /* walk the packet tree (in order) and rebuild the app layer data */
    (void)ubi_trTraverse(s->dataPtr, TraverseFunc, &bd);

    if(bd.total_size != stream_size)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "stream_size(%u) != bd.total_size(%u), "
                                "that's bad, m'kay?\n", stream_size, bd.total_size););

        stream_size = bd.total_size;

        stream_pkt->pkth->caplen = ETHERNET_HEADER_LEN + IP_HEADER_LEN + 
            TCP_HEADER_LEN + stream_size;
        stream_pkt->pkth->len = stream_pkt->pkth->caplen;

        stream_pkt->iph->ip_len = htons( (u_short) (IP_HEADER_LEN + 
                                                    TCP_HEADER_LEN + stream_size) );

    }

    if(s4data.stop_traverse)
    {
        stream_pkt->dsize = s4data.stop_seq - s->base_seq;

        if(stream_pkt->dsize > bd.total_size)
        {
            stream_pkt->dsize = bd.total_size;
        }

        stream_pkt->pkth->caplen = ETHERNET_HEADER_LEN + IP_HEADER_LEN + 
            TCP_HEADER_LEN + stream_pkt->dsize;

        stream_pkt->pkth->len = stream_pkt->pkth->caplen;

        stream_pkt->iph->ip_len = htons( (u_short) (IP_HEADER_LEN + 
                                                    TCP_HEADER_LEN + p->dsize) );
    }
    else
    {
        stream_pkt->dsize = stream_size;
    }

    s4data.stop_traverse = 0;

    stream_pkt->tcp_option_count = 0;
    stream_pkt->tcp_lastopt_bad = 0;
    stream_pkt->packet_flags = (PKT_REBUILT_STREAM|PKT_STREAM_EST);

    ssn = p->ssnptr;

    if(stream_pkt->sp == ssn->client.port)
    {
        stream_pkt->packet_flags |= PKT_FROM_CLIENT;
    }
    else
    {
        stream_pkt->packet_flags |= PKT_FROM_SERVER;
    }
    
    DEBUG_WRAP(DebugMessage(DEBUG_STREAM,
                            "Built packet with %u byte payload, "
                            "Direction: %s\n",
                            stream_pkt->dsize,
                            (stream_pkt->packet_flags & PKT_FROM_SERVER) ? "from_server" : "from_client"););

    pc.rebuilt_tcp++;


    
#ifdef DEBUG
    if(stream_pkt->packet_flags & PKT_FROM_CLIENT)
    {
        DebugMessage(DEBUG_STREAM, "packet is from client!\n");
    }

    if(stream_pkt->packet_flags & PKT_FROM_SERVER)
    {
        DebugMessage(DEBUG_STREAM, "packet is from server!\n");
    }


    
    ClearDumpBuf();
    PrintIPPkt(stdout, IPPROTO_TCP, stream_pkt);
    ClearDumpBuf();
    printf("Printing app buffer at %p, size %d\n", 
           stream_pkt->data, stream_pkt->dsize);
    PrintNetData(stdout, stream_pkt->data, stream_pkt->dsize);
    ClearDumpBuf();
#endif

}


int CheckPorts(u_int16_t port1, u_int16_t port2)
{
    if(s4data.assemble_ports[port1] || s4data.assemble_ports[port2])
    {
        return 1;
    }

    return 0;
}

void OpenStatsFile()
{
    time_t curr_time;      /* place to stick the clock data */
    char logdir[STD_BUF];
    int value;
    StatsLogHeader hdr;

    bzero(logdir, STD_BUF);
    curr_time = time(NULL);

    if(stats_log->filename[0] == '/')
        value = snprintf(logdir, STD_BUF, "%s%s.%lu", 
                         chrootdir == NULL ? "" : chrootdir, stats_log->filename, 
                         curr_time);
    else
        value = snprintf(logdir, STD_BUF, "%s%s/%s.%lu",
                         chrootdir == NULL ? "" : chrootdir, pv.log_dir, 
                         stats_log->filename, curr_time);

    if(value == -1)
    {
        FatalError("ERROR: log file logging path and file name are "
                   "too long, aborting!\n");
    }

    printf("stream4:OpenStatsFile() Opening %s\n", logdir);

    if((stats_log->fp=fopen(logdir, "w+")) == NULL)
    {
        FatalError("stream4:OpenStatsFile(%s): %s\n", logdir, strerror(errno));
    }

    hdr.magic = STATS_MAGIC;
    hdr.version_major = 1;
    hdr.version_minor = 81;
    hdr.timezone = 1;

    if(fwrite((char *)&hdr, sizeof(hdr), 1, stats_log->fp) != 1)
    {
        FatalError("stream4:OpenStatsFile(): %s\n", strerror(errno));
    }
        
    fflush(stats_log->fp);

    /* keep a copy of the filename for later reference */
    if(stats_log->filename != NULL)
    {
        free(stats_log->filename);

        stats_log->filename = strdup(logdir);
    }

    return;
}



void WriteSsnStats(BinStats *bs)
{
    fwrite(bs, sizeof(BinStats), 1, stats_log->fp);
    return;
}

static void TcpAction(Session *ssn, Packet *p, int action, int direction, 
                      u_int32_t pkt_seq, u_int32_t pkt_ack)
{
    Event event;
    
    if(action == ACTION_NOTHING)
    {
        DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "returning -- action nothing\n"););
        return;
    }
    else 
    {
        if(action & ACTION_SET_SERVER_ISN)
        {
            ssn->server.isn = pkt_seq;
            ssn->client.win_size = ntohs(p->tcph->th_win);

            if(pkt_ack == (ssn->client.isn+1))
            {
                ssn->client.last_ack = ssn->client.isn+1;
            }
            else
            {
                /* we got a messed up response from the server */
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                        "WARNING: Got unexpected SYN ACK from server!\n");
                           DebugMessage(DEBUG_STREAM, 
                                        "expected: 0x%X   received: 0x%X\n"););
                ssn->client.last_ack = pkt_ack;
            }
        }

        /* complete a three way handshake */
        if(action & ACTION_COMPLETE_TWH)
        {
            /* this should be isn+1 */
            if(pkt_ack == ssn->server.isn+1)
            {
                ssn->server.last_ack = ssn->server.isn+1;
            }
            else
            {
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: Fishy TWH from client "
                                        "(0x%X:%d->0x%X:%d) (ack: 0x%X  isn: 0x%X)\n", 
                                        p->iph->ip_src.s_addr, p->sp, p->iph->ip_dst.s_addr, 
                                        p->dp, pkt_ack, ssn->server.isn););
   
                ssn->server.last_ack = pkt_ack;
            }

            ssn->server.base_seq = ssn->server.last_ack;
            ssn->client.base_seq = ssn->client.last_ack;
        }

        /* 
         * someone sent data in their SYN packet, classic sign of someone
         * doing bad things (or a bad ip stack/piece of equipment)
         */
        if(action & ACTION_DATA_ON_SYN)
        {
            if(p->tcph->th_flags & TH_SYN)
            {
                /* alert... */
                if(s4data.evasion_alerts)
                {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_DATA_ON_SYN, 1, 0, 5, 0);
                    CallAlertFuncs(p, STREAM4_DATA_ON_SYN_STR ,NULL, &event);
                    CallLogFuncs(p, STREAM4_DATA_ON_SYN_STR, NULL, &event);
                }

                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: Data on SYN packet!\n"););
                return;
            }
        }

        if(action & ACTION_INC_PORT)
        {
            ssn->client.port++;
        }

        /* client sent some data */
        if(action & ACTION_ACK_CLIENT_DATA)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "client.base_seq(%u) client.last_ack(%u) offset(%u)\n",
                                    ssn->client.base_seq,ssn->client.last_ack,
                                    (ssn->client.last_ack - ssn->client.base_seq)););
    
            ssn->server.current_seq = pkt_seq;
            ssn->client.last_ack = pkt_ack;

            if(ssn->client.base_seq != 0 && ssn->client.last_ack != 0)
            {
                Stream *s;

                s = &ssn->client;

                if((ssn->client.last_ack - ssn->client.base_seq) > ssn->flush_point 
                   && ubi_trCount(s->dataPtr) > 1)
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Flushing Client packet buffer "
                                            "(%d bytes a: 0x%X b: 0x%X pkts: %d)\n",
                                            (ssn->client.last_ack - ssn->client.base_seq), 
                                            ssn->client.last_ack, ssn->client.base_seq,
                                            ubi_trCount(s->dataPtr)););
                    
                    if(s4data.reassemble_client)
                    {
                        FlushStream(&ssn->client, p, REVERSE);
                    }

                    ssn->client.base_seq = ssn->client.last_ack;
                }
            }
        }

        /* server sent some data */
        if(action & ACTION_ACK_SERVER_DATA)
        {
            ssn->client.current_seq = pkt_seq;
            ssn->server.last_ack = pkt_ack;

            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "server.base_seq(%u) server.last_ack(%u)\n",
                                    ssn->server.base_seq,ssn->server.last_ack););

            if(ssn->server.base_seq != 0 && ssn->server.last_ack != 0)
            {
                Stream *s;

                s = &ssn->server;

                if((ssn->server.last_ack - ssn->server.base_seq) > ssn->flush_point
                   && ubi_trCount(s->dataPtr) > 1)
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Flushing Server packet buffer "
                                            "(%d bytes a: 0x%X b: 0x%X)\n",
                                            (ssn->server.last_ack - ssn->server.base_seq),
                                            ssn->server.last_ack, ssn->server.base_seq););
                    
                    if(s4data.reassemble_server)
                    {
                        FlushStream(&ssn->server, p, REVERSE);
                    }

                    ssn->server.base_seq = ssn->server.last_ack;
                }
            }
        }
        
        if(action & ACTION_ALERT_NMAP_FINGERPRINT)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_NMAP_FINGERPRINT, 1, 0, 5, 0);
            CallAlertFuncs(p, STREAM4_STEALTH_NMAP_FINGERPRINT_STR, NULL, &event);
            CallLogFuncs(p, STREAM4_STEALTH_NMAP_FINGERPRINT_STR, NULL, &event);
            return;
        }

        if(action & ACTION_FLUSH_SERVER_STREAM)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "flushing server stream, ending "
                                    "session: %d\n", s4data.reassemble_server););

            if(s4data.reassemble_server)
            {
                ssn->server.last_ack--;

                if(direction == FROM_SERVER)
                {
                    FlushStream(&ssn->server, p, NO_REVERSE);
                }
                else
                {
                    FlushStream(&ssn->server, p, REVERSE);
                }
            }
        }

        if(action & ACTION_FLUSH_CLIENT_STREAM)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "flushing client stream, ending "
                                    "session\n"););

            if(s4data.reassemble_client)
            {
                ssn->client.last_ack--;

                if(direction == FROM_CLIENT)
                {
                    FlushStream(&ssn->client, p, NO_REVERSE);
                }
                else
                {
                    FlushStream(&ssn->client, p, REVERSE);
                }
            }
        }

        if(action & ACTION_DROP_SESSION)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Dumping session\n"););
            DeleteSession(ssn, p->pkth->ts.tv_sec);
            p->ssnptr = NULL;
        }
    }
}

static void TcpActionAsync(Session *ssn, Packet *p, int action, int direction, 
                           u_int32_t pkt_seq, u_int32_t pkt_ack)
{
    Event event;

    if(direction == FROM_CLIENT)
    {
        if(!ssn->client.isn)
        {
            ssn->client.isn = pkt_seq;
        }

        ssn->client.last_ack = pkt_seq;
        
    }
    else
    {
        if(!ssn->client.isn)
        {
            ssn->client.isn = pkt_seq;
        }

        ssn->server.last_ack = pkt_seq;
    }
        
    
    if(action == ACTION_NOTHING)
    {
        return;
    }
    else 
    {
        if(action & ACTION_SET_SERVER_ISN)
        {
            ssn->server.isn = pkt_seq;
            ssn->client.win_size = ntohs(p->tcph->th_win);

            if(pkt_ack == (ssn->client.isn+1))
            {
                ssn->client.last_ack = ssn->client.isn+1;
            }
            else
            {
                /* we got a messed up response from the server */
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, 
                                        "WARNING: Got unexpected SYN ACK from server!\n");
                           DebugMessage(DEBUG_STREAM, 
                                        "expected: 0x%X   received: 0x%X\n"););
                ssn->client.last_ack = pkt_ack;
            }
        }

        /* complete a three way handshake */
        if(action & ACTION_COMPLETE_TWH)
        {
            /* this should be isn+1 */
            if(pkt_ack == ssn->server.isn+1)
            {
                ssn->server.last_ack = ssn->server.isn+1;
            }
            else
            {
                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: Fishy TWH from client "
                                        "(0x%X:%d->0x%X:%d) (ack: 0x%X  isn: 0x%X)\n", 
                                        p->iph->ip_src.s_addr, p->sp, p->iph->ip_dst.s_addr, 
                                        p->dp, pkt_ack, ssn->server.isn););
   
                ssn->server.last_ack = pkt_ack;
            }

            ssn->server.base_seq = ssn->server.last_ack;
            ssn->client.base_seq = ssn->client.last_ack;
        }

        /* 
         * someone sent data in their SYN packet, classic sign of someone
         * doing bad things (or a bad ip stack/piece of equipment)
         */
        if(action & ACTION_DATA_ON_SYN)
        {
            if(p->tcph->th_flags & TH_SYN)
            {
                /* alert... */
                if(s4data.evasion_alerts)
                {
                    SetEvent(&event, GENERATOR_SPP_STREAM4, 
                             STREAM4_DATA_ON_SYN, 1, 0, 5, 0);
                    CallAlertFuncs(p, STREAM4_DATA_ON_SYN_STR ,NULL, &event);
                    CallLogFuncs(p, STREAM4_DATA_ON_SYN_STR, NULL, &event);
                }

                DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "WARNING: Data on SYN packet!\n"););
                return;
            }
        }

        if(action & ACTION_INC_PORT)
        {
            ssn->client.port++;
        }

        /* client sent some data */
        if(action & ACTION_ACK_CLIENT_DATA)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "client.base_seq(%u) client.last_ack(%u)\n",
                                    ssn->client.base_seq,ssn->client.last_ack););
    
            ssn->server.current_seq = pkt_seq;
            ssn->client.last_ack = pkt_ack;

            if(ssn->client.base_seq != 0 && ssn->client.last_ack != 0)
            {
                Stream *s;

                s = &ssn->client;

                if((ssn->client.last_ack - ssn->client.base_seq) > ssn->flush_point 
                   && ubi_trCount(s->dataPtr) > 1)
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Flushing Client packet buffer "
                                            "(%d bytes a: 0x%X b: 0x%X pkts: %d)\n",
                                            (ssn->client.last_ack - ssn->client.base_seq), 
                                            ssn->client.last_ack, ssn->client.base_seq,
                                            ubi_trCount(s->dataPtr)););
                    
                    if(s4data.reassemble_client)
                    {
                        FlushStream(&ssn->client, p, REVERSE);
                    }

                    ssn->client.base_seq = ssn->client.last_ack;
                }
            }
        }

        /* server sent some data */
        if(action & ACTION_ACK_SERVER_DATA)
        {
            ssn->client.current_seq = pkt_seq;
            ssn->server.last_ack = pkt_ack;

            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "server.base_seq(%u) server.last_ack(%u)\n",
                                    ssn->server.base_seq,ssn->server.last_ack););

            if(ssn->server.base_seq != 0 && ssn->server.last_ack != 0)
            {
                Stream *s;

                s = &ssn->server;

                if((ssn->server.last_ack - ssn->server.base_seq) > ssn->flush_point
                   && ubi_trCount(s->dataPtr) > 1)
                {
                    DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Flushing Server packet buffer "
                                            "(%d bytes a: 0x%X b: 0x%X)\n",
                                            (ssn->server.last_ack - ssn->server.base_seq),
                                            ssn->server.last_ack, ssn->server.base_seq););
                    
                    if(s4data.reassemble_server)
                    {
                        FlushStream(&ssn->server, p, REVERSE);
                    }

                    ssn->server.base_seq = ssn->server.last_ack;
                }
            }
        }
        
        if(action & ACTION_ALERT_NMAP_FINGERPRINT)
        {
            SetEvent(&event, GENERATOR_SPP_STREAM4, 
                     STREAM4_STEALTH_NMAP_FINGERPRINT, 1, 0, 5, 0);
            CallAlertFuncs(p, STREAM4_STEALTH_NMAP_FINGERPRINT_STR, NULL, &event);
            CallLogFuncs(p, STREAM4_STEALTH_NMAP_FINGERPRINT_STR, NULL, &event);
            return;
        }

        if(action & ACTION_FLUSH_SERVER_STREAM)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "flushing server stream, ending "
                                    "session: %d\n", s4data.reassemble_server););

            if(s4data.reassemble_server)
            {
                ssn->server.last_ack--;

                if(direction == FROM_SERVER)
                {
                    FlushStream(&ssn->server, p, NO_REVERSE);
                }
                else
                {
                    FlushStream(&ssn->server, p, REVERSE);
                }
            }
        }

        if(action & ACTION_FLUSH_CLIENT_STREAM)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "flushing client stream, ending "
                                    "session\n"););

            if(s4data.reassemble_client)
            {
                ssn->client.last_ack--;

                if(direction == FROM_CLIENT)
                {
                    FlushStream(&ssn->client, p, NO_REVERSE);
                }
                else
                {
                    FlushStream(&ssn->client, p, REVERSE);
                }
            }
        }

        if(action & ACTION_DROP_SESSION)
        {
            DEBUG_WRAP(DebugMessage(DEBUG_STREAM, "Dumping session\n"););
            DeleteSession(ssn, p->pkth->ts.tv_sec);
            p->ssnptr = NULL;
        }
    }
}

