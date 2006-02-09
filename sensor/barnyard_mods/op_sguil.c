/* $Id: op_sguil.c,v 1.17 2006/02/09 22:12:47 bamm Exp $ */

/*
** Copyright (C) 2002-2006 Robert (Bamm) Visscher <bamm@sguil.net> 
**
** This program is distributed under the terms of version 1.0 of the
** Q Public License.  See LICENSE.QPL for further details.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
**
*/

/*
** op_sguil is the sguil  output plugin for barnyard (http://barnyard.sf.net).
** For more information about sguil see http://www.sguil.net
*/

/*********************************************************************
*                I  N  C  L  U  D  E  S                              *
*********************************************************************/

/* Std includes */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <time.h>
#include <errno.h>
#include <unistd.h>
#include <ctype.h>

#include "strlcpyu.h"
#include "ConfigFile.h"
#include "plugbase.h"
#include "mstring.h"
#include "sid.h"
#include "classification.h"
#include "util.h"
#include "input-plugins/dp_log.h"
#include "op_plugbase.h"
#include "op_decode.h"
#include "event.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

/* Yeah TCL! */
#include <tcl.h>

/* Output plug-in API functions */
static int OpSguil_Setup(OutputPlugin *, char *args);
static int OpSguil_Exit(OutputPlugin *);
static int OpSguil_Start(OutputPlugin *, void *);
static int OpSguil_Stop(OutputPlugin *);
static int OpSguil_Log(void *, void *);
static int OpSguil_LogConfig(OutputPlugin *outputPlugin);

typedef struct _OpSguil_Data
{
    char *sensor_name;
    char *tag_path;
    char *passwd;
    u_int16_t sensor_id;
    u_int32_t event_id;
    u_int16_t agent_port;
    int agent_sock;
} OpSguil_Data;

#define MAX_MSG_LEN 2048
#define STD_BUFFER 128

int OpSguil_AppendIPHdrData(Tcl_DString *list, Packet *p);
int OpSguil_AppendICMPData(Tcl_DString *list, Packet *p);
int OpSguil_AppendTCPData(Tcl_DString *list, Packet *p);
int OpSguil_AppendUDPData(Tcl_DString *list, Packet *p);
int OpSguil_AppendPayloadData(Tcl_DString *list, Packet *p);
int OpSguil_SensorAgentConnect(OpSguil_Data *);
//int OpSguil_SensorAgentAuth(OpSguil_Data *);
int OpSguil_SensorAgentInit(OpSguil_Data *);
int OpSguil_RTEventMsg(OpSguil_Data *data, char *msg);
int OpSguil_SendAgentMsg(OpSguil_Data *data, char *msg);
int OpSguil_RecvAgentMsg();
OpSguil_Data *OpSguil_ParseArgs(char *);


/* init routine makes this processor available for dataprocessor directives */
void OpSguil_Init()
{
    OutputPlugin *outputPlugin;
                                                                                                                          
    outputPlugin = RegisterOutputPlugin("sguil", "log");
    outputPlugin->setupFunc = OpSguil_Setup;
    outputPlugin->exitFunc = OpSguil_Exit;
    outputPlugin->startFunc = OpSguil_Start;
    outputPlugin->stopFunc = OpSguil_Stop;
    outputPlugin->outputFunc = OpSguil_Log;
    outputPlugin->logConfigFunc = OpSguil_LogConfig;
                                                                                                                          
}

/* Setup the output plugin, process any arguments, link the functions to
 * the output functional node
 */
int OpSguil_Setup(OutputPlugin *outputPlugin, char *args)
{
    /* setup the run time context for this output plugin */
    outputPlugin->data = OpSguil_ParseArgs(args);
                                                                                                                          
    return 0;
}
                                                                                                                          
/* Inverse of the setup function, free memory allocated in Setup
 * can't free the outputPlugin since it is also the list node itself
 */
int OpSguil_Exit(OutputPlugin *outputPlugin)
{
    return 0;
}

/*
 * this function gets called at start time, you should open any output files
 * or establish DB connections, etc, here
 */
int OpSguil_Start(OutputPlugin *outputPlugin, void *spool_header)
{
    OpSguil_Data *data = (OpSguil_Data *)outputPlugin->data;

    if(data == NULL)
        FatalError("ERROR: Unable to find context for Sguil startup!\n");
                                                                                                                          
    if(pv.verbose)
        OpSguil_LogConfig(outputPlugin);
                                                                                                                          
    /* Figure out out sensor_name */
    if(data->sensor_name == NULL)
    {
         /* See if the user used the ProgVar config hostname: */
         if(pv.hostname != NULL)
         {
             data->sensor_name = pv.hostname;
         }
         else
         {
             FatalError("ERROR: Unable to determine hostname.");
         }
    }
   
    /* Connect to sensor_agent */
    OpSguil_SensorAgentConnect(data);

    /* Initialize - get sid and next cid */
    if(pv.verbose)
        LogMessage("Waiting for sid and cid from sensor_agent.\n");
    OpSguil_SensorAgentInit(data);

    if(pv.verbose)
    {

        LogMessage("Sensor Name: %s\n", data->sensor_name);
        LogMessage("Agent Port: %u\n", data->agent_port);

    }

/*
**    if(SensorAgentAuth(data))
**        FatalError("OpSguil: Authentication failed.\n");
**
**    if(pv.verbose)
**        LogMessage("OpSguil: Authentication successful.);
*/

    return 0;
}

int OpSguil_Stop(OutputPlugin *outputPlugin)
{
    OpSguil_Data *data = (OpSguil_Data *)outputPlugin->data;
                                                                                                                          
    if(data == NULL)
        FatalError("ERROR: Unable to find context for Sguil startup!\n");
                                                                                                                          
    return 0;
}

int OpSguil_LogConfig(OutputPlugin *outputPlugin)
{

    OpSguil_Data *data = NULL;
                                                                                                                                           
    if(!outputPlugin || !outputPlugin->data)
        return -1;
                                                                                                                                           
    data = (OpSguil_Data *)outputPlugin->data;

    LogMessage("OpSguil configured\n");

    /* XXX We need to print the configuration details here */

    return 0;
}


int OpSguil_Log(void *context, void *ul_data)
{

    char timestamp[TIMEBUF_SIZE];
    Sid *sid = NULL;
    ClassType *class_type;
    UnifiedLogRecord *record = (UnifiedLogRecord *)ul_data;
    OpSguil_Data *data = (OpSguil_Data *)context;
    Packet p;
    char buffer[STD_BUFFER];
    Tcl_DString list;

    bzero(buffer, STD_BUFFER);

    //LogMessage("Event id ==> %u\n", record->log.event.event_id);
    //LogMessage("Ref time ==> %lu\n", record->log.event.ref_time.tv_sec);

    /* Sig info */
    sid = GetSid(record->log.event.sig_generator, record->log.event.sig_id);
    if(sid == NULL)
        sid = FakeSid(record->log.event.sig_generator, record->log.event.sig_id);
    sid->rev = record->log.event.sig_rev;

    class_type = GetClassType(record->log.event.classification);
    
    /* Here we build our RT event to send to sguild. The event is built with a
    ** proper tcl list format. 
    ** RT FORMAT:
    ** 
    **     0      1    2     3          4            5                  6                7
    ** {RTEVENT} {0} {sid} {cid} {sensor name} {snort event_id} {snort event_ref} {snort ref_time} 
    **
    **     8         9      10      11         12         13          14
    ** {sig_gen} {sig id} {rev} {message} {timestamp} {priority} {class_type} 
    **
    **      15            16           17           18           19       20        21
    ** {sip (dec)} {sip (string)} {dip (dec)} {dip (string)} {ip proto} {ip ver} {ip hlen}
    **
    **    22       23      24        25        26       27       28
    ** {ip tos} {ip len} {ip id} {ip flags} {ip off} {ip ttl} {ip csum}
    **
    **      29         30           31        32         33
    ** {icmp type} {icmp code} {icmp csum} {icmp id} {icmp seq}
    ** 
    **     34         35
    ** {src port} {dst port}
    **
    **     36        37        38        39        40         41        42          43
    ** {tcp seq} {tcp ack} {tcp off} {tcp res} {tcp flags} {tcp win} {tcp csum} {tcp urp}
    **
    **     44        45
    ** {udp len} {udp csum}
    **
    **      46
    ** {data payload}
    */

    Tcl_DStringInit(&list);

    /* RTEVENT */
    Tcl_DStringAppendElement(&list, "RTEVENT");

    /* Status - 0 */
    Tcl_DStringAppendElement(&list, "0");

    /* Sensor ID  (sid) */
    sprintf(buffer, "%u", data->sensor_id);
    Tcl_DStringAppendElement(&list, buffer);

    /* Event ID (cid) */
    sprintf(buffer, "%u", data->event_id);
    Tcl_DStringAppendElement(&list, buffer);

    /* Sensor Name */
    Tcl_DStringAppendElement(&list, data->sensor_name);

    /* Snort Event ID */
    sprintf(buffer, "%u", record->log.event.event_id);
    Tcl_DStringAppendElement(&list, buffer);

    /* Snort Event Ref */
    sprintf(buffer, "%u", record->log.event.event_reference);
    Tcl_DStringAppendElement(&list, buffer);

    /* Snort Event Ref Time */
    if(record->log.event.ref_time.tv_sec == 0) 
    {
        Tcl_DStringAppendElement(&list, "");
    }
    else
    {    
        RenderTimestamp(record->log.event.ref_time.tv_sec, timestamp, TIMEBUF_SIZE);
        Tcl_DStringAppendElement(&list, timestamp);
    }

    /* Generator ID */
    sprintf(buffer, "%d", sid->gen);
    Tcl_DStringAppendElement(&list, buffer);

    /* Signature ID */
    sprintf(buffer, "%d", sid->sid);
    Tcl_DStringAppendElement(&list, buffer);

    /* Signature Revision */
    sprintf(buffer, "%d", sid->rev);
    Tcl_DStringAppendElement(&list, buffer);

    /* Signature Msg */
    Tcl_DStringAppendElement(&list, sid->msg);

    /* Packet Timestamp */
    RenderTimestamp(record->log.pkth.ts.tv_sec, timestamp, TIMEBUF_SIZE);
    Tcl_DStringAppendElement(&list, timestamp);

    /* Alert Priority */
    sprintf(buffer, "%u", record->log.event.priority);
    Tcl_DStringAppendElement(&list, buffer);

    /* Alert Classification */
    if (class_type == NULL)
    {
        Tcl_DStringAppendElement(&list, "unknown");
    }
    else
    {
        Tcl_DStringAppendElement(&list, class_type->type);
    }

    /* Pull decoded info from the packet */
    if(DecodePacket(&p, &record->log.pkth, record->pkt + 2) == 0)
    {
        if(p.iph)
        {
            int i;

            /* Add IP header */
            OpSguil_AppendIPHdrData(&list, &p);

            /* Add icmp || udp || tcp data */
            if(!(p.pkt_flags & PKT_FRAG_FLAG))
            {

                switch(p.iph->ip_proto)
                {
                    case IPPROTO_ICMP:
                        OpSguil_AppendICMPData(&list, &p);
                        break;

                    case IPPROTO_TCP:
                        OpSguil_AppendTCPData(&list, &p);
                        break;

                    case IPPROTO_UDP:
                        OpSguil_AppendUDPData(&list, &p);
                        break;

                    default:
                        for(i = 0; i < 17; ++i)
                        {
                            Tcl_DStringAppendElement(&list, "");
                        }
                        break;
                }

            }
            else
            {
                /* Null out TCP/UDP/ICMP fields */
                for(i = 0; i < 17; ++i)
                {
                    Tcl_DStringAppendElement(&list, "");
                }
            }
        }
        else
        {

            /* No IP Header. */
            int i;
            for(i = 0; i < 31; ++i)
            {
                Tcl_DStringAppendElement(&list, "");
            }
        }

        /* Add payload data */
        OpSguil_AppendPayloadData(&list, &p);

    }
    else
    {
        /* ack! an event without a packet. Append 32 fillers */
        int i;
        for(i = 0; i < 32; ++i)
        {
            Tcl_DStringAppendElement(&list, "");
        }
    }

    /* Send msg to sensor_agent */
    if (OpSguil_RTEventMsg(data, Tcl_DStringValue(&list)))
        FatalError("Unable to send RT Events to sensor agent.\n");

    /* Free! */
    Tcl_DStringFree(&list);

    /* bump the event id */
    ++data->event_id;

    return 0;
}

int OpSguil_RTEventMsg(OpSguil_Data *data, char *msg)
{

    char tmpRecvMsg[MAX_MSG_LEN];

    /* Send Msg */
    OpSguil_SendAgentMsg(data, msg);

    /* Get confirmation */
    memset(tmpRecvMsg,0x0,MAX_MSG_LEN);
    if(OpSguil_RecvAgentMsg(data, tmpRecvMsg) == 1 )
    {

        if(pv.verbose)
         LogMessage("Retrying\n");

        OpSguil_RTEventMsg(data, msg);

    }
    else
    {

        char **toks;
        int num_toks;

        if(pv.verbose)
            LogMessage("Received: %s", tmpRecvMsg);

        /* Parse the response */
        toks = mSplit(tmpRecvMsg, " ", 2, &num_toks, 0);
        if(strcasecmp("Confirm", toks[0]) != 0 || atoi(toks[1]) != data->event_id )
        {

            FatalError("Expected Confirm %u and got: %s\n", data->event_id, tmpRecvMsg);

        }

        FreeToks(toks, num_toks);

    }

    return 0;
 
}

OpSguil_Data *OpSguil_ParseArgs(char *args)
{

    OpSguil_Data *op_data;
                                                                                                                          
    op_data = (OpSguil_Data *)SafeAlloc(sizeof(OpSguil_Data));
                                                                                                                          
    if(args != NULL)
    {
        char **toks;
        int num_toks;
        int i;
        /* parse out your args */
        toks = mSplit(args, ",", 31, &num_toks, '\\');
        for(i = 0; i < num_toks; ++i)
        {
            char **stoks;
            int num_stoks;
            char *index = toks[i];
            while(isspace((int)*index))
                ++index;
            stoks = mSplit(index, " ", 2, &num_stoks, 0);
            if(strcasecmp("agent_port", stoks[0]) == 0)
            {
                if(num_stoks > 1)
                    op_data->agent_port = atoi(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name,
                            file_line, index);
            }
            else if(strcasecmp("tag_path", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->tag_path == NULL)
                    op_data->tag_path = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name,
                            file_line, index);
            }
            else if(strcasecmp("sensor_name", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->sensor_name == NULL)
                    op_data->sensor_name = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name,
                            file_line, index);
            }
            else if(strcasecmp("passwd", stoks[0]) == 0)
            {
                if(num_stoks > 1 && op_data->passwd == NULL)
                    op_data->passwd = strdup(stoks[1]);
                else
                    LogMessage("Argument Error in %s(%i): %s\n", file_name,
                            file_line, index);
            }
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

    if (op_data->agent_port == 0)
    {
        op_data->agent_port = 7735;
    }

    return op_data;

}

int OpSguil_AppendIPHdrData(Tcl_DString *list, Packet *p)
{
    char buffer[STD_BUFFER];

    bzero(buffer, STD_BUFFER);

    sprintf(buffer, "%u", ntohl(p->iph->ip_src.s_addr));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u.%u.%u.%u",
#if defined(WORDS_BIGENDIAN)
           (p->iph->ip_src.s_addr & 0xff000000) >> 24,
           (p->iph->ip_src.s_addr & 0x00ff0000) >> 16,
           (p->iph->ip_src.s_addr & 0x0000ff00) >> 8,
           (p->iph->ip_src.s_addr & 0x000000ff));
#else
           (p->iph->ip_src.s_addr & 0x000000ff),
           (p->iph->ip_src.s_addr & 0x0000ff00) >> 8,
           (p->iph->ip_src.s_addr & 0x00ff0000) >> 16,
           (p->iph->ip_src.s_addr & 0xff000000) >> 24);
#endif
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", ntohl(p->iph->ip_dst.s_addr));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u.%u.%u.%u",
#if defined(WORDS_BIGENDIAN)
           (p->iph->ip_dst.s_addr & 0xff000000) >> 24,
           (p->iph->ip_dst.s_addr & 0x00ff0000) >> 16,
           (p->iph->ip_dst.s_addr & 0x0000ff00) >> 8,
           (p->iph->ip_dst.s_addr & 0x000000ff));
#else
           (p->iph->ip_dst.s_addr & 0x000000ff),
           (p->iph->ip_dst.s_addr & 0x0000ff00) >> 8,
           (p->iph->ip_dst.s_addr & 0x00ff0000) >> 16,
           (p->iph->ip_dst.s_addr & 0xff000000) >> 24);
#endif
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", p->iph->ip_proto);
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", IP_VER(p->iph));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", IP_HLEN(p->iph));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", p->iph->ip_tos);
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", ntohs(p->iph->ip_len));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", ntohs(p->iph->ip_id));
    Tcl_DStringAppendElement(list, buffer);
                                                                                                                                                 
#if defined(WORDS_BIGENDIAN)
                                                                                                                                                 
    sprintf(buffer, "%u", ((p->iph->ip_off & 0xE000) >> 13));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", htons(p->iph->ip_off & 0x1FFF));
    Tcl_DStringAppendElement(list, buffer);
                                                                                                                                                 
#else
                                                                                                                                                 
    sprintf(buffer, "%u", ((p->iph->ip_off & 0x00E0) >> 5));
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", htons(p->iph->ip_off & 0xFF1F));
    Tcl_DStringAppendElement(list, buffer);
 
#endif
 
    sprintf(buffer, "%u", p->iph->ip_ttl);
    Tcl_DStringAppendElement(list, buffer);
    sprintf(buffer, "%u", htons(p->iph->ip_csum));
    Tcl_DStringAppendElement(list, buffer);

    return 0;
}

int OpSguil_AppendICMPData(Tcl_DString *list, Packet *p)
{

    int i;
    char buffer[STD_BUFFER];

    bzero(buffer, STD_BUFFER);

    if(!p->icmph)
    {

        /* Null out ICMP fields */
        for(i=0; i < 5; i++)
            Tcl_DStringAppendElement(list, "");

    }
    else
    {

        /* ICMP type */
        sprintf(buffer, "%u", p->icmph->icmp_type);
        Tcl_DStringAppendElement(list, buffer);

        /* ICMP code */
        sprintf(buffer, "%u", p->icmph->icmp_code);
        Tcl_DStringAppendElement(list, buffer);
    
        /* ICMP CSUM */
        sprintf(buffer, "%u", ntohs(p->icmph->icmp_csum));
        Tcl_DStringAppendElement(list, buffer);

        /* Append other ICMP data if we have it */
        if(p->icmph->icmp_type == ICMP_ECHOREPLY || 
           p->icmph->icmp_type == ICMP_ECHO ||
           p->icmph->icmp_type == ICMP_TIMESTAMP ||
           p->icmph->icmp_type == ICMP_TIMESTAMPREPLY ||
           p->icmph->icmp_type == ICMP_INFO_REQUEST || 
           p->icmph->icmp_type == ICMP_INFO_REPLY)
        {

            /* ICMP ID */
            sprintf(buffer, "%u", htons(p->icmph->icmp_hun.ih_idseq.icd_id));
            Tcl_DStringAppendElement(list, buffer);

            /* ICMP Seq */
            sprintf(buffer, "%u", htons(p->icmph->icmp_hun.ih_idseq.icd_seq));
            Tcl_DStringAppendElement(list, buffer);

        }
        else
        {

            /* Add two empty elements */
            for(i=0; i < 2; i++)
                Tcl_DStringAppendElement(list, "");
    
        }

    }

    /* blank out 12 elements */
    for(i = 0; i < 12; i++)
        Tcl_DStringAppendElement(list, "");

    return 0;

}

int OpSguil_AppendTCPData(Tcl_DString *list, Packet *p)
{

    /*
    **     33        34        35        36        37         38        39          40
    ** {tcp seq} {tcp ack} {tcp off} {tcp res} {tcp flags} {tcp win} {tcp csum} {tcp urp}
    **
    */

    int i;
    char buffer[STD_BUFFER];

    bzero(buffer, STD_BUFFER);

    /* empty elements for icmp data */
    for(i=0; i < 5; i++)
        Tcl_DStringAppendElement(list, "");

    if(!p->tcph)
    {

        /* Null out TCP fields */
        for(i=0; i < 10; i++)
            Tcl_DStringAppendElement(list, "");

    }
    else
    {

        sprintf(buffer, "%u", p->sp);
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", p->dp);
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohl(p->tcph->th_seq));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohl(p->tcph->th_ack));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", TCP_OFFSET(p->tcph));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", TCP_X2(p->tcph));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", p->tcph->th_flags);
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohs(p->tcph->th_win));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohs(p->tcph->th_sum));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohs(p->tcph->th_urp));
        Tcl_DStringAppendElement(list, buffer);

    }

    /* empty elements for UDP data */
    for(i=0; i < 2; i++)
        Tcl_DStringAppendElement(list, "");

    return 0;

}

int OpSguil_AppendUDPData(Tcl_DString *list, Packet *p)
{

    int i;
    char buffer[STD_BUFFER];

    bzero(buffer, STD_BUFFER);
 
    /* empty elements for icmp data */
    for(i=0; i < 5; i++)
        Tcl_DStringAppendElement(list, "");

    if(!p->udph)
    {
        
        /* Null out port info */
        for(i=0; i < 2; i++)
            Tcl_DStringAppendElement(list, "");

    }
    else
    {

        /* source and dst port */
        sprintf(buffer, "%u", p->sp);
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", p->dp);
        Tcl_DStringAppendElement(list, buffer);

    }

    /* empty elements for tcp data */
    for(i=0; i < 8; i++)
        Tcl_DStringAppendElement(list, "");

    if(!p->udph)
    {
        
        /* Null out UDP info */
        for(i=0; i < 2; i++)
            Tcl_DStringAppendElement(list, "");

    }
    else
    {

        sprintf(buffer, "%u", ntohs(p->udph->uh_len));
        Tcl_DStringAppendElement(list, buffer);

        sprintf(buffer, "%u", ntohs(p->udph->uh_chk));
        Tcl_DStringAppendElement(list, buffer);

    }

    return 0;

}

int OpSguil_AppendPayloadData(Tcl_DString *list, Packet *p)
{

    char *hex_payload;

    if(p->dsize)
    {
        hex_payload = fasthex(p->data, p->dsize);
        Tcl_DStringAppendElement(list, hex_payload);
        free(hex_payload);
    } else {
        Tcl_DStringAppendElement(list, "");
    }

    return 0;

}


int OpSguil_SensorAgentConnect(OpSguil_Data *data)
{

    int sockfd;
    struct sockaddr_in my_addr;

    while(1)
    {

        if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
        {
            FatalError("Cannot open a local socket.\n");
            return 1;
        }

        my_addr.sin_family = AF_INET;
        my_addr.sin_port = htons(data->agent_port);
        my_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        memset(&(my_addr.sin_zero), '\0', 8);

    
        if (connect(sockfd, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) < 0)
        {
            LogMessage("Cannot connect to localhost on TCP port %u.\n",
                        data->agent_port);
            close(sockfd);
            LogMessage("Waiting 15 secs to try again.\n");
            if (BarnyardSleep(15))
            {
                LogMessage("Received Kill Signal...");
                CleanExit(0);
            }

        }
        else
        {

            data->agent_sock = sockfd;
            LogMessage("Connected to localhost on %u.\n",
                        data->agent_port);
            return 0;

        }

    }

}

/*
int OpSguil_SensorAgentAuth(OpSguil_Data *data)
{

    Tcl_DString auth_cmd;

    Tcl_DStringInit(&auth_cmd);
    Tcl_DStringAppendElement(auth_cmd, "AUTH");
    Tcl_DStringAppendElement(auth_cmd, data->passwd);
    
    
}
*/

/* Request sensor ID (sid) and next cid from sensor_agent */
int OpSguil_SensorAgentInit(OpSguil_Data *data)
{

    char tmpSendMsg[MAX_MSG_LEN];
    char tmpRecvMsg[MAX_MSG_LEN];

    /* Send our Request */
    snprintf(tmpSendMsg, MAX_MSG_LEN, "SidCidRequest %s", data->sensor_name);
    OpSguil_SendAgentMsg(data, tmpSendMsg);

    /* Get the Results */
    memset(tmpRecvMsg,0x0,MAX_MSG_LEN);
    if(OpSguil_RecvAgentMsg(data, tmpRecvMsg) == 1 )
    {

        OpSguil_SensorAgentInit(data);

    }
    else
    {

        char **toks;
        int num_toks;

        if(pv.verbose)
            LogMessage("Received: %s", tmpRecvMsg);

        /* Parse the response */
        toks = mSplit(tmpRecvMsg, " ", 3, &num_toks, 0);
        if(strcasecmp("SidCidResponse", toks[0]) == 0)
        {

            data->sensor_id = atoi(toks[1]);
            data->event_id = atoi(toks[2]);

        }
        else
        {

            FatalError("Expected SidCidResponse and got: %s\n", tmpRecvMsg);

        }

        FreeToks(toks, num_toks);

        if(pv.verbose)
         LogMessage("Sensor ID: %u\nLast cid: %u\n", data->sensor_id, data->event_id);

        /* Use the next event_id */
        ++data->event_id;

    }

    return 0;

}

int OpSguil_SendAgentMsg(OpSguil_Data *data, char *msg)
{

    int schars;
    size_t len;
    char *tmpMsg;

    len = strlen(msg)+2;

    tmpMsg = SafeAlloc(len);

    snprintf(tmpMsg, len, "%s\n", msg);

    if((schars = send(data->agent_sock, tmpMsg, sizeof(char)*strlen(tmpMsg), 0)) < 0)
    {

        if(pv.verbose)
         LogMessage("Lost connection to sensor_agent.\n");

        /* Resend our msg */
        OpSguil_SendAgentMsg(data, msg);

    }

    if(pv.verbose)
     LogMessage("Sent: %s", tmpMsg);

    free(tmpMsg);

    return 0;

}

/* I love google. http://pont.net/socket/prog/tcpServer.c */
int OpSguil_RecvAgentMsg(OpSguil_Data *data, char *line_to_return) {
                                                                                                                                    
  static int rcv_ptr=0;
  static char rcv_msg[MAX_MSG_LEN];
  static int n;
  struct timeval tv;
  fd_set read_fds;
  int offset;
                                                                                                                                    
  offset=0;
  /* wait 15 secs for our response */
  tv.tv_sec = 15;
  tv.tv_usec = 0;

  FD_ZERO(&read_fds);
  FD_SET(data->agent_sock, &read_fds);

  while(1) {

    /* Wait for response from sguild */
    select(data->agent_sock+1, &read_fds, NULL, NULL, &tv);
                                                                                                                                    
    if (!(FD_ISSET(data->agent_sock, &read_fds)))
    {
        /* timed out */
        if(pv.verbose)
         LogMessage("Timed out waiting for response.\n");

        return 1;
    }
    else
    {
      if(rcv_ptr==0) {
                                                                                                                                    
        memset(rcv_msg,0x0,MAX_MSG_LEN);
        n = recv(data->agent_sock, rcv_msg, MAX_MSG_LEN, 0);
        if (n<0) {
          LogMessage("ERROR: Unable to read data.\n");
          /* Reconnect to sensor_agent */
          OpSguil_SensorAgentConnect(data);
        } else if (n==0) {
          LogMessage("ERROR: Connecton closed by client\n");
          close(data->agent_sock);
          /* Reconnect to sensor_agent */
          OpSguil_SensorAgentConnect(data);
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

}

