/*
** Copyright (C) 1998-2002 Martin Roesch <roesch@sourcefire.com>
** Copyright (C) 1999,2000,2001 Patrick Mullen <p_mullen@linuxrc.net>
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

/* $Id: spp_portscan.c,v 1.1 2003/04/30 22:08:02 bamm Exp $ */
/* Snort Portscan Preprocessor Plugin
    by Patrick Mullen <p_mullen@linuxrc.net>
    Version 0.2.14
*/

/* This is a modified version of spp_portsan. It is meant to be used in
 * conjuction with sguil (Snort GUI for Lamerz). Changes include using
 * CallLogFuncs and the output format.
*/

#include <sys/types.h>
#include <string.h>
// Bammkkkk
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#ifndef WIN32
    #include <sys/time.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
#endif /* !WIN32 */
#include <time.h>

#include "rules.h"
#include "log.h"
#include "util.h"
#include "debug.h"
#include "generators.h"
#include "detect.h"
#include "log.h"
#include "plugbase.h"
#include "parser.h"
#include "mstring.h"

#include "snort.h"


void PortscanInit(u_char *);
void ParsePortscanArgs(u_char *);
void PortscanPreprocFunction(Packet *);
void ExtractHeaderInfo(Packet*, struct in_addr*, struct in_addr*, u_short*, u_short*);

void PortscanIgnoreHostsInit(u_char*);
#define MODNAME "spp_portscan"
/*
BUGS:
I dare say the connection information reported at the end of a scan is
   wildly inaccurate.  Search for "ZDNOTE CONNECTION INFORMATION" for
   more details.

TODO:

configuration file
scans to multiple networks
log scan packet contents
- Once a host has been determined to be scanning, automatically log packets from
  that host to reduce memory requirements.
documentation
function descriptions
distributed portscans

*/


/* Definitions for scan types */
struct spp_timeval
{
    time_t tv_sec;
    time_t tv_usec;
};

typedef enum _scanType
{
    sNONE = 0, sUDP = 1, sSYN = 2, sSYNFIN = 4, sFIN = 8, sNULL = 16,
    sXMAS = 32, sFULLXMAS = 64, sRESERVEDBITS = 128, sVECNA = 256, sNOACK = 512, sNMAPID = 1024,
    sSPAU = 2048, sINVALIDACK = 4096
} ScanType;

/* Definitions for log levels */
typedef enum _logLevel
{
    lNONE = 0, lFILE = 1, lEXTENDED = 2, lPACKET = 4
} LogLevel;


/* Structures for keeping track of connection information. */
typedef struct _connectionInfo
{
    ScanType scanType;
    u_short sport;
    u_short dport;
    struct spp_timeval timestamp;
    char tcpFlags[9];       /* Eight flags and a NULL */
    u_char *packetData;
    struct _connectionInfo *prevNode;
    struct _connectionInfo *nextNode;
}               ConnectionInfo;

typedef struct _destinationInfo
{
    struct in_addr daddr;
    int numberOfConnections;
    ConnectionInfo *connectionsList;
    struct _destinationInfo *prevNode;
    struct _destinationInfo *nextNode;
}                DestinationInfo;

typedef struct _sourceInfo
{
    struct in_addr saddr;
    int numberOfConnections;
    int numberOfDestinations;
    int numberOfTCPConnections;
    int numberOfUDPConnections;

    /*
     * ZDNOTE CONNECTION INFORMATION The totals statistics are generally
     * inaccurate and for general information of the severity of a scan,
     * rather than a hard and fast count of what was scanned. To provide 100%
     * accurate statistics, the architecture would have to be heavily
     * modified.  This should probably be done anyway, but not today.
     * 
     * Ways these counts will be inaccurate: 1) Hosts is incorrect if a host is
     * rescanned after all connection information is cleared 2) Connections
     * counts are incorrect if same ports are rescanned after they have
     * already been reported. 3) Probably more.  This is a little more
     * difficult to do reliably than I realized.  Ah, well.
     */
    int totalNumberOfTCPConnections;
    int totalNumberOfUDPConnections;
    int totalNumberOfDestinations;

    struct spp_timeval firstPacketTime;
    struct spp_timeval lastPacketTime;
    int reportStealth;

    int stealthScanUsed;
    int scanDetected;
    struct spp_timeval reportTime;  /* last time we reported on this
                     * source's activities */
    DestinationInfo *destinationsList;
    u_int32_t event_id;
    struct _sourceInfo *prevNode;
    struct _sourceInfo *nextNode;
}           SourceInfo;

typedef struct _scanList
{
    SourceInfo *listHead;
    SourceInfo *lastSource;
    long numberOfSources;   /* must be as large as address space */
}         ScanList;

typedef struct _serverNode  /* for keeping track of our network's servers */
{
    IpAddrSet *address;
    /*
     * u_long address; u_long netmask;
     */
    char ignoreFlags;
    struct _serverNode *nextNode;
}           ServerNode;



typedef struct _CPConfig
{
    u_int32_t classification;
    u_int32_t priority;
} CPConfig;


/** FUNCTION PROTOTYPES **/
/* Add connection information */
int NewScan(ScanList *, Packet *, ScanType);
ConnectionInfo *NewConnection(Packet *, ScanType);
ConnectionInfo *AddConnection(ConnectionInfo *, Packet *, ScanType);
DestinationInfo *NewDestination(Packet *, ScanType);
DestinationInfo *AddDestination(DestinationInfo *, Packet *, ScanType);
SourceInfo *NewSource(Packet *, ScanType);
SourceInfo *AddSource(SourceInfo *, Packet *, ScanType);

/* Remove connection information */
void ExpireConnections(ScanList *, struct spp_timeval, struct spp_timeval);
void RemoveConnection(ConnectionInfo *);
void RemoveDestination(DestinationInfo *);
void RemoveSource(SourceInfo *);
void ClearConnectionInfoFromSource(SourceInfo *);

/* Logging functions */
void LogScanInfoToSeparateFile(SourceInfo *);
void AlertIntermediateInfo(SourceInfo *);

/* Miscellaneous functions */
ScanList *CreateScanList(void);
ScanType CheckTCPFlags(u_char);
int IsServer(Packet *);

/* For portscan-ignorehosts */
IpAddrSet *PortscanAllocAddrNode();
void PortscanParseIP(char *);
void CreateServerList(u_char *);
IpAddrSet *PortscanIgnoreAllocAddrNode(ServerNode *);
void PortscanIgnoreParseIP(char *, ServerNode *);

/* Global variables */
ScanList *scanList;
ServerNode *serverList;
ScanType scansToWatch;
CPConfig configdata;

/*u_long homeNet, homeNetMask;*/
IpAddrSet *homeAddr;
char homeFlags;
struct spp_timeval maxTime;
long maxPorts;
LogLevel logLevel;
enum _timeFormat
{
    tLOCAL, tGMT
}           timeFormat;
// Bammkkkk
long GetMilliseconds() 
{
    struct timeval  tv;
    gettimeofday(&tv, NULL);

    return (long)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}
char *logDirName;
char *sensorName;
int packetLogSize;      /* Number of data bytes to log per scan
                 * packet */

/* external globals from rules.c */
extern char *file_name;
extern int file_line;
extern u_int32_t event_id;


ConnectionInfo *NewConnection(Packet * p, ScanType scanType)
{
    ConnectionInfo *newConnection = (ConnectionInfo *) malloc(sizeof(ConnectionInfo));

    newConnection->prevNode = NULL;
    newConnection->nextNode = NULL;

    newConnection->scanType = scanType;
    /*
     * timestamp provided by libpcap.  This is available realtime and during
     * -r playback
     */
    newConnection->timestamp.tv_sec = p->pkth->ts.tv_sec;
    newConnection->timestamp.tv_usec = p->pkth->ts.tv_usec;

    /* The ports are already supposed to be in host order from decode.c */
    newConnection->sport = p->sp;
    newConnection->dport = p->dp;

    switch(p->iph->ip_proto)
    {
        case IPPROTO_TCP:
            CreateTCPFlagString(p, newConnection->tcpFlags);

            /* ZDNOTE PACKET LOGGING */
            if(logLevel & lPACKET)
            {
                /*
                 * Determine buffer size = header size + lower(datasize,
                 * packetLogSize)
                 */
                /* Allocate memory */
                /* Copy data */
            }
            break;

        case IPPROTO_UDP:
            strncpy(newConnection->tcpFlags, "\0", 1);

            /* ZDNOTE PACKET LOGGING */
            if(logLevel & lPACKET)
            {
                /*
                 * Determine buffer size = header size + lower(datasize,
                 * packetLogSize)
                 */
                /* Allocate memory */
                /* Copy data */
            }
            break;

        default:
            /* This should never happen because it's already filtered. */
            FatalError(MODNAME ": NewConnection(): Invalid protocol! (%d)\n", p->iph->ip_proto);
            break;
    }

    return(newConnection);
}

ConnectionInfo *AddConnection(ConnectionInfo * currentConnection, Packet * p, ScanType scanType)
{
    if(currentConnection->nextNode)
        FatalError(MODNAME ":  AddConnection():  Not at end of connection list!");

    currentConnection->nextNode = NewConnection(p, scanType);
    currentConnection->nextNode->prevNode = currentConnection;

    return(currentConnection->nextNode);
}


DestinationInfo *NewDestination(Packet * p, ScanType scanType)
{
    DestinationInfo *newDestination = (DestinationInfo *) malloc(sizeof(DestinationInfo));

    newDestination->prevNode = NULL;
    newDestination->nextNode = NULL;
    newDestination->daddr = p->iph->ip_dst;
    newDestination->connectionsList = NewConnection(p, scanType);
    newDestination->numberOfConnections = 1;

    return(newDestination);
}


DestinationInfo *AddDestination(DestinationInfo * currentDestination, Packet * p,
                                ScanType scanType)
{
    if(currentDestination->nextNode)
        FatalError(MODNAME ":  AddDestination():  Not at end of destination list!");

    currentDestination->nextNode = NewDestination(p, scanType);
    currentDestination->nextNode->prevNode = currentDestination;
    return(currentDestination->nextNode);
}


SourceInfo *NewSource(Packet * p, ScanType scanType)
{
    SourceInfo *newSource = (SourceInfo *) malloc(sizeof(SourceInfo));

    newSource->prevNode = NULL;
    newSource->nextNode = NULL;
    newSource->saddr = p->iph->ip_src;
    newSource->numberOfConnections = 1;

    newSource->firstPacketTime.tv_sec = p->pkth->ts.tv_sec;
    newSource->firstPacketTime.tv_usec = p->pkth->ts.tv_usec;
    newSource->lastPacketTime.tv_sec = p->pkth->ts.tv_sec;
    newSource->lastPacketTime.tv_usec = p->pkth->ts.tv_usec;

    if(scanType == sUDP)
    {
        newSource->numberOfUDPConnections = 1;
        newSource->numberOfTCPConnections = 0;

        DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
				": NewSource(): %s->numberOfUDPConnections = 1, TCP = 0\n",
				inet_ntoa(newSource->saddr)););
    }
    else
    {
        newSource->numberOfTCPConnections = 1;
        newSource->numberOfUDPConnections = 0;

	DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
				": NewSource(): %s->numberOfTCPConnections = 1, UDP = 0\n",
				inet_ntoa(newSource->saddr)););
    }

    newSource->totalNumberOfTCPConnections = 0;
    newSource->totalNumberOfUDPConnections = 0;
    newSource->stealthScanUsed = 0; /* This needs to be set elsewhere */
    newSource->scanDetected = 0;
    newSource->destinationsList = NewDestination(p, scanType);
    newSource->numberOfDestinations = 1;
    newSource->totalNumberOfDestinations = 1;
    newSource->reportStealth = 0;   /* This needs to be set elsewhere */

    return(newSource);
}


SourceInfo *AddSource(SourceInfo * currentSource, Packet * p, ScanType scanType)
{
    if(currentSource->nextNode)
        FatalError(MODNAME ":  AddSource():  Not at end of source list!");

    currentSource->nextNode = NewSource(p, scanType);
    currentSource->nextNode->prevNode = currentSource;

    return(currentSource->nextNode);
}


void RemoveConnection(ConnectionInfo * delConnection)
{
    /*
     * If there is a prev and/or next node, make them point to the proper
     * places.  Otherwise, just delete this node.
     */
    if(delConnection->prevNode || delConnection->nextNode)
    {
        if(delConnection->prevNode)
        {
            delConnection->prevNode->nextNode = delConnection->nextNode;
        }
        else if(delConnection->nextNode)
        {
            delConnection->nextNode->prevNode = NULL;
        }
        if(delConnection->nextNode)
        {
            delConnection->nextNode->prevNode = delConnection->prevNode;
        }
        else if(delConnection->prevNode)
        {
            delConnection->prevNode->nextNode = NULL;
        }
    }
    free(delConnection);
}


void RemoveDestination(DestinationInfo * delDestination)
{
    /*
     * If there is a prev and/or next node, make them point to the proper
     * places.  Otherwise, just delete this node.
     */
    if(delDestination->prevNode || delDestination->nextNode)
    {
        if(delDestination->prevNode)
        {
            delDestination->prevNode->nextNode = delDestination->nextNode;
        }
        else if(delDestination->nextNode)
        {
            delDestination->nextNode->prevNode = NULL;
        }
        if(delDestination->nextNode)
        {
            delDestination->nextNode->prevNode = delDestination->prevNode;
        }
        else if(delDestination->prevNode)
        {
            delDestination->prevNode->nextNode = NULL;
        }
    }
    free(delDestination);
}


void RemoveSource(SourceInfo * delSource)
{
    /*
     * If there is a prev and/or next node, make them point to the proper
     * places.  Otherwise, just delete this node.
     */
    if(delSource->prevNode || delSource->nextNode)
    {
        if(delSource->prevNode)
        {
            delSource->prevNode->nextNode = delSource->nextNode;
        }
        else if(delSource->nextNode)
        {
            delSource->nextNode->prevNode = NULL;
        }
        if(delSource->nextNode)
        {
            delSource->nextNode->prevNode = delSource->prevNode;
        }
        else if(delSource->prevNode)
        {
            delSource->prevNode->nextNode = NULL;
        }
    }
    free(delSource);
}


/* Go through each connection and remove any connections that are old.  If
   the removal of a node makes a parent node empty, remove that node, all
   the way back to the root.
*/
void ExpireConnections(ScanList * scanList, struct spp_timeval watchPeriod,
                       struct spp_timeval currentTime)
{
    SourceInfo *currentSource = scanList->listHead, *tmpSource;
    DestinationInfo *currentDestination, *tmpDestination;
    ConnectionInfo *currentConnection, *tmpConnection;

    /* Empty list. Get out of here. */
    if(!scanList->listHead)
        return;

    while(currentSource)
    {
        /*
         * If this source host is scanning us, we don't want to lose any
         * connections so go back to top.
         */
        if(currentSource->scanDetected)
        {
            currentSource = currentSource->nextNode;
            continue;
        }
        currentDestination = currentSource->destinationsList;

        while(currentDestination)
        {
            currentConnection = currentDestination->connectionsList;

            while(currentConnection)
            {
                if(currentConnection->timestamp.tv_sec + watchPeriod.tv_sec < currentTime.tv_sec)
                {
                    /* Expire the connection */
                    tmpConnection = currentConnection;
                    currentConnection = currentConnection->nextNode;

                    /*
                     * If this is the first connection, we need to update
                     * connectionsList.
                     */
                    if(tmpConnection->prevNode == NULL)
                    {
                        currentDestination->connectionsList = tmpConnection->nextNode;
                    }
                    if(tmpConnection->scanType == sUDP)
                    {
                        currentSource->numberOfUDPConnections--;

                        DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
						": ExpireConnections(): %s->numberOfUDPConnections-- (%d)\n",
						inet_ntoa(currentSource->saddr),
						currentSource->numberOfUDPConnections););

                    }
                    else
                    {
                        currentSource->numberOfTCPConnections--;
			DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
						": ExpireConnections(): %s->numberOfTCPConnections-- (%d)\n",
						inet_ntoa(currentSource->saddr),
						currentSource->numberOfTCPConnections););

                    }

                    RemoveConnection(tmpConnection);
                    currentSource->numberOfConnections--;
                    currentDestination->numberOfConnections--;

                }
                else
                {
                    currentConnection = currentConnection->nextNode;
                }
            }

            tmpDestination = currentDestination;
            currentDestination = currentDestination->nextNode;

            if(tmpDestination->numberOfConnections == 0)
            {
                if(tmpDestination->prevNode == NULL)
                {
                    currentSource->destinationsList = tmpDestination->nextNode;
                }
                RemoveDestination(tmpDestination);
                currentSource->numberOfDestinations--;
            }
        }

        tmpSource = currentSource;
        currentSource = currentSource->nextNode;

        if(tmpSource->numberOfDestinations == 0)
        {
            /* If this is the first source, we need to update scanList. */
            if(tmpSource->prevNode == NULL)
            {
                /* This is fine, even if tmpSource->nextNode is NULL */
                scanList->listHead = tmpSource->nextNode;
            }
            RemoveSource(tmpSource);
            scanList->numberOfSources--;
        }
    }

    if(scanList->numberOfSources == 0)
    {
        scanList->listHead = NULL;
    }
}


/*
    Add the connection information and return the
    new number of connections for this host
*/
int NewScan(ScanList * scanList, Packet * p, ScanType scanType)
{
    SourceInfo *currentSource = scanList->listHead;
    DestinationInfo *currentDestination;
    ConnectionInfo *currentConnection;
    int matchFound = 0;

    struct in_addr saddr;
    struct in_addr daddr;
    u_short sport;
    u_short dport;

    /* If list is empty, create the list and add this entry. */
    if(!scanList->listHead)
    {
        scanList->listHead = NewSource(p, scanType);
        scanList->numberOfSources = 1;
        scanList->lastSource = scanList->listHead;
        return(scanList->listHead->numberOfConnections);
    }
    ExtractHeaderInfo(p, &saddr, &daddr, &sport, &dport);

    while(!matchFound)
    {
        if(currentSource->saddr.s_addr == saddr.s_addr)
        {
            currentDestination = currentSource->destinationsList;

            if(currentSource->destinationsList == NULL)
            {
                currentSource->destinationsList = NewDestination(p, scanType);
                currentSource->numberOfConnections++;

                if(scanType == sUDP)
                {
                    currentSource->numberOfUDPConnections++;
                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
					    ": NewScan(): %s->numberOfUDPConnections++ (%d)\n",
					    inet_ntoa(currentSource->saddr),
					    currentSource->numberOfUDPConnections););
                }
                else
                {
                    currentSource->numberOfTCPConnections++;
                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
					    ": NewScan(): %s->numberOfTCPConnections++ (%d)\n",
					    inet_ntoa(currentSource->saddr),
					    currentSource->numberOfTCPConnections););
                }

                currentSource->numberOfDestinations++;
                matchFound = 1;
            }
            currentDestination = currentSource->destinationsList;

            while(!matchFound)
            {
                if(currentDestination->daddr.s_addr == daddr.s_addr)
                {
                    currentConnection = currentDestination->connectionsList;

                    while(!matchFound)
                    {
                        /*
                         * There should be error checking for
                         * currentConnection == NULL, but that should never
                         * happen.
                         */
                        if(currentConnection == NULL)
                            FatalError(MODNAME ": currentConnection is NULL!!!??\n");

                        if((currentConnection->dport == dport) && (currentConnection->scanType == scanType))
                        {
                            /*
                             * If the same exact connection already exists,
                             * just update the timestamp.
                             */
                            currentConnection->timestamp.tv_sec = p->pkth->ts.tv_sec;
                            currentConnection->timestamp.tv_usec = p->pkth->ts.tv_usec;
                            currentConnection->sport = sport;
                            matchFound = 1;
                        }
                        else
                        {
                            /*
                             * If not at end of list, keep going, otherwise
                             * create a node.
                             */
                            if(!currentConnection->nextNode)
                            {
                                currentConnection = AddConnection(currentConnection, p, scanType);
                                currentSource->numberOfConnections++;

                                if(scanType == sUDP)
                                {
                                    currentSource->numberOfUDPConnections++;
                                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
							    ": NewScan(): %s->numberOfUDPConnections++ (%d)\n",
							    inet_ntoa(currentSource->saddr),
							    currentSource->numberOfUDPConnections););

                                }
                                else
                                {
                                    currentSource->numberOfTCPConnections++;
                                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
							    ": NewScan(): %s->numberOfTCPConnections++ (%d)\n",
							    inet_ntoa(currentSource->saddr),
							    currentSource->numberOfTCPConnections););
                                }

                                currentDestination->numberOfConnections++;
                                matchFound = 1;
                            }
                            else
                                currentConnection = currentConnection->nextNode;
                        }
                    }
                }
                else
                {
                    if(!currentDestination->nextNode)
                    {
                        currentDestination = AddDestination(currentDestination, p, scanType);
                        currentSource->numberOfConnections++;

                        if(scanType == sUDP)
                        {
                            currentSource->numberOfUDPConnections++;
                            DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
						    ": NewScan(): %s->numberOfUDPConnections++ (%d)\n",
						    inet_ntoa(currentSource->saddr),
						    currentSource->numberOfUDPConnections););
                        }
                        else
                        {
                            currentSource->numberOfTCPConnections++;
                            DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
						    ": NewScan(): %s->numberOfTCPConnections++ (%d)\n",
						    inet_ntoa(currentSource->saddr),
						    currentSource->numberOfTCPConnections););

                        }

                        currentSource->numberOfDestinations++;
                        currentSource->totalNumberOfDestinations++;
                        matchFound = 1;
                    }
                    else
                        currentDestination = currentDestination->nextNode;
                }
            }
        }
        else
        {
            if(!currentSource->nextNode)
            {
                currentSource = AddSource(currentSource, p, scanType);
                currentSource->numberOfConnections = 1;

                if(scanType == sUDP)
                {
                    currentSource->numberOfUDPConnections = 1;
                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,
					    MODNAME ": NewScan(): %s->numberOfUDPConnections = 1 \n",
					    inet_ntoa(currentSource->saddr)););
                }
                else
                {
                    currentSource->numberOfTCPConnections = 1;
		    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
					    ": NewScan(): %s->numberOfTCPConnections = 1\n",
					    inet_ntoa(currentSource->saddr)););

                }

                scanList->numberOfSources++;
                matchFound = 1;
            }
            else
                currentSource = currentSource->nextNode;
        }
    }

    scanList->lastSource = currentSource;
    return(currentSource->numberOfConnections);
}


ScanList *CreateScanList(void)
{
    ScanList *newList = (ScanList *) malloc(sizeof(ScanList));

    newList->listHead = NULL;
    newList->lastSource = NULL;
    newList->numberOfSources = 0;

    return(newList);
}



void PortscanPreprocFunction(Packet * p)
{
    /*
     * The main loop.  Whenever this is called, first we expire connections
     * so we don't get false positives from stale connections.  Then we add
     * the new connection information and check if the latest connection has
     * passed the threshold.  If it has or if a stealth technique was used,
     * we immediately report the scan.  Then we go through the list and any
     * host that has been flagged as doing a portscan and has passed the
     * necessary amount of time between reports and has connections stored
     * are reported and cleared.  Any host that has been flagged as doing a
     * portscan and has passed the necessary amount of time between reports
     * and does not have connections stored has the portscan flag cleared and
     * will automatically be flushed at next call.
     */

    SourceInfo *currentSource;
    ScanType scanType;
    struct spp_timeval currTime;
    char logMessage[180];
    int numPorts;
    Event event;

    /* Only do processing on IP Packets */
    if(p->iph == NULL)
    {
        return;
    }

    if(p->packet_flags & PKT_REBUILT_STREAM)
    {
        return;
    }

    /*
     * Here we check if it is a protocol we are watching and if it is a
     * destination we are watching.  If either fails, we return abruptly.
     */
    switch(p->iph->ip_proto)
    {
        case IPPROTO_TCP:
            if(p->tcph == NULL)
            {
                /*
                 * ZDNOTE Fragmented packets have IPH set to NULL so `nmap -f`
                 * defeats SPP, at least until reassembly or the header pointer
                 * is fixed.
                 */
                return;
            }
            DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,"spp_portscan: Got TCP pkt\n"););
            scanType = CheckTCPFlags(p->tcph->th_flags);
            break;

        case IPPROTO_UDP:
            /*
             * We no longer check for NULL UDP headers here, because it really
             * doesn't matter anymore.  We don't access it.  We just use p->[sd]p
             * instead.
             */
            scanType = sUDP;
            break;

        default:
            /* The packet isn't a protocol we watch, so get out of here. */
            return;         /*** RETURN ***/
            break;
    }

    /*
     * For speed, we're going to drop out right now if this packet is not any
     * type of scan.  My assumption is most packets on the network are not
     * going to be any type of scan packet (not even SYN or UDP), so this
     * extra check will be faster in the long run.
     */
    if(!scanType)
        return;

    /*
     * The checks above are faster, so now that we know this packet is
     * interesting we'll check the address.
     */
    if(!CheckAddrPort(homeAddr, 0, 0, p,
                (ANY_DST_PORT | homeFlags), CHECK_DST))
    {
        return;
    }
    /*
     * If we ignore SYN and UDP scans from this host (presumably because it's
     * a server), clear out those flags so we don't get false alarms. If it's
     * a server, we also need to make sure there are no reserved bits set
     * because otherwise "2*S*****" shows as UNKNOWN instead of as SYN w/
     * RESERVEDBITS.  The beast below makes sure we are actually watching for
     * RB scans.  The previous version would have let servers be left as SYN
     * scans if a reserved bit was set.
     */
    if(IsServer(p) && !(scanType & sRESERVEDBITS & scansToWatch))
    {
        scanType &= ~(sSYN | sUDP);
    }
    if(scanType & scansToWatch)
    {
        currTime.tv_sec = p->pkth->ts.tv_sec;
        currTime.tv_usec = p->pkth->ts.tv_usec;
        ExpireConnections(scanList, maxTime, currTime);

        /*
         * If more than maxPorts connections made or if stealth scan
         * technique was used, mark this as a portscan.
         */

        numPorts = NewScan(scanList, p, scanType);

        /* Timestamp info for statistics */
        scanList->lastSource->lastPacketTime = currTime;

        if((numPorts > maxPorts) || (scanType & ~(sSYN | sUDP)))
        {
            if(scanType & ~(sSYN | sUDP))
            {
                scanList->lastSource->stealthScanUsed = 1;
                scanList->lastSource->reportStealth = 1;
            }
            if(!scanList->lastSource->scanDetected)
            {
                if(scanList->lastSource->stealthScanUsed)
                {
                    if(pv.alert_interface_flag)
                    {
                        sprintf(logMessage, 
                                MODNAME ": PORTSCAN DETECTED on %s to port %d "
                                "from %s (STEALTH)", 
                                PRINT_INTERFACE(pv.interfaces[0]), 
                                p->dp,
                                inet_ntoa(scanList->lastSource->saddr));
                    }
                    else
                    {
                        sprintf(logMessage, 
                                MODNAME ": PORTSCAN DETECTED to port %d from "
                                "%s (STEALTH)", 
                                p->dp,
                                inet_ntoa(scanList->lastSource->saddr));
                    }
                }
                else
                {
                    if(pv.alert_interface_flag)
                    {
                        sprintf(logMessage, MODNAME 
                                ": PORTSCAN DETECTED on %s from %s"
                                " (THRESHOLD %ld connections exceeded in %ld seconds)",
                                PRINT_INTERFACE(pv.interfaces[0]), 
                                inet_ntoa(scanList->lastSource->saddr), maxPorts,
                                (long int) (currTime.tv_sec - 
                                            scanList->lastSource->firstPacketTime.tv_sec));
                    }
                    else
                    {
                        sprintf(logMessage, 
                                MODNAME ": PORTSCAN DETECTED from %s"
                                " (THRESHOLD %ld connections exceeded in %ld seconds)",
                                inet_ntoa(scanList->lastSource->saddr), maxPorts,
                                (long int) (currTime.tv_sec - 
                                            scanList->lastSource->firstPacketTime.tv_sec));
                    }
                }

                SetEvent(&event, GENERATOR_SPP_PORTSCAN, PORTSCAN_SCAN_DETECT, 
                        1, 0, 5, 0);
                CallLogFuncs(p , logMessage, NULL, &event);
                scanList->lastSource->scanDetected = 1;
                scanList->lastSource->reportTime = currTime;
                scanList->lastSource->event_id = event_id;
            }
        }
        /* See if there's anyone we can snitch on.  ;)  */
        currentSource = scanList->listHead;
        while(currentSource)
        {
            if(currentSource->scanDetected)
            {
                if(currentSource->reportTime.tv_sec + maxTime.tv_sec < currTime.tv_sec)
                {
                    if(currentSource->numberOfConnections == 0)
                    {
                        /* Portscan stopped.  Clear flag. */
                        sprintf(logMessage, MODNAME ": End of portscan from %s: TOTAL time(%lds) hosts(%d) TCP(%d) UDP(%d)%s",
                                inet_ntoa(currentSource->saddr),
                                (long int) (currentSource->lastPacketTime.tv_sec - currentSource->firstPacketTime.tv_sec),
                                currentSource->totalNumberOfDestinations,
                                currentSource->totalNumberOfTCPConnections,
                                currentSource->totalNumberOfUDPConnections,
                                (currentSource->reportStealth) ? " STEALTH" : "");
                        SetEvent(&event, GENERATOR_SPP_PORTSCAN, 
                                PORTSCAN_SCAN_END, 1, 0, 0, 
                                currentSource->event_id);
                        CallAlertFuncs(NULL , logMessage, NULL, &event);
                        currentSource->scanDetected = 0;
                    }
                    else
                    {
                        /* This is where we do the real logging */
                        if(logLevel & lFILE)
                            LogScanInfoToSeparateFile(currentSource);
                        if(logLevel & lEXTENDED)
                            AlertIntermediateInfo(currentSource);

                        currentSource->totalNumberOfTCPConnections += 
                            currentSource->numberOfTCPConnections;
                        currentSource->totalNumberOfUDPConnections += 
                            currentSource->numberOfUDPConnections;

                        ClearConnectionInfoFromSource(currentSource);
                        currentSource->stealthScanUsed = 0;
                        currentSource->reportTime = currTime;
                    }
                }
            }
            currentSource = currentSource->nextNode;
        }
    }
}



void ClearConnectionInfoFromSource(SourceInfo * currentSource)
{
    DestinationInfo *currentDestination, *tmpDestination;
    ConnectionInfo *currentConnection, *tmpConnection;

    currentDestination = currentSource->destinationsList;
    while(currentDestination)
    {
        currentConnection = currentDestination->connectionsList;
        while(currentConnection)
        {
            tmpConnection = currentConnection;
            currentConnection = currentConnection->nextNode;

            if(tmpConnection->scanType == sUDP)
            {
                currentSource->numberOfUDPConnections--;
                DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
					": ClearConnectionInfoFromSource(): %s->numberOfUDPConnections-- (%d)\n",
					inet_ntoa(currentSource->saddr), currentSource->numberOfUDPConnections););

            }
            else
            {
                currentSource->numberOfTCPConnections--;
                DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, MODNAME
					": ClearConnectionInfoFromSource(): %s->numberOfTCPConnections-- (%d)\n",
					inet_ntoa(currentSource->saddr), currentSource->numberOfTCPConnections););
            }

            RemoveConnection(tmpConnection);
            currentDestination->numberOfConnections--;
            currentSource->numberOfConnections--;
        }
        tmpDestination = currentDestination;
        currentDestination = currentDestination->nextNode;
        RemoveDestination(tmpDestination);
        currentSource->numberOfDestinations--;
    }
    currentSource->destinationsList = NULL;
}


void SetupPortscan(void)
{
    RegisterPreprocessor("portscan", PortscanInit);
}


void PortscanInit(u_char * args)
{
    ParsePortscanArgs(args);
    scanList = CreateScanList();

    /*
     * We set serverList to NULL here so if portscan-ignorehosts is used it
     * must be set after portscan.  This is necessary to make sure we don't
     * check an empty list.
     */
    serverList = NULL;
    AddFuncToPreprocList(PortscanPreprocFunction);
}


ScanType CheckTCPFlags(u_char th_flags)
{
    u_char th_flags_cleaned;
    ScanType scan = sNONE;

    /*
     * Strip off the reserved bits for the testing, but flag that a scan is
     * being done.
     */
    th_flags_cleaned = th_flags & ~(R_RES1 | R_RES2);

    /* I'm disabling reserved bits scan detection until we can get a
     * handle on ECN, we're seeing far too many false positives with
     * this code right now -MFR
     */ 
    /*if(th_flags != th_flags_cleaned)
    {
        scan = sRESERVEDBITS;
    }*/
    /*
     * Most TCP packets will have the ACK bit set, so split that out quickly.
     * Any scans which use ACK (like Full-XMAS) must be added to this part.
     * Otherwise, it goes in the !ACK section. In addition, anything that is
     * !ACK && !SYN eventually gets flagged as something.  This is to
     * hopefully detect new stealth scan types.
     */
    if(th_flags_cleaned & R_ACK)
    {

        /*
         * This is from ipt_unclean.c from the netfilter package.  We are
         * allowing packets which are valid and flagging the rest as
         * INVALIDACK, if it's not already listed as some other scan.
         */
        switch(th_flags_cleaned)
        {
            case (R_ACK):
            case (R_SYN | R_ACK):
            case (R_FIN | R_ACK):
            case (R_RST | R_ACK):
            case (R_ACK | R_PSH):
            case (R_ACK | R_URG):
            case (R_ACK | R_URG | R_PSH):
            case (R_FIN | R_ACK | R_PSH):
            case (R_FIN | R_ACK | R_URG):
            case (R_FIN | R_ACK | R_URG | R_PSH):
            case (R_RST | R_ACK | R_PSH):   /* Found through numerous false
                             * alerts. */
                /* Nothing.  This is legitimate traffic. */
                break;

            case (R_SYN | R_RST | R_ACK | R_FIN | R_PSH | R_URG):
                scan |= sFULLXMAS;
                break;

            case (R_SYN | R_PSH | R_ACK | R_URG):
                scan |= sSPAU;
                break;

            default:
                scan |= sINVALIDACK;
                break;
        }
    }
    else
    {
        /*
         * ZDNOTE This could/should be optimized, but just by having the
         * check for SYN or RST being first makes this faster.  (Anything
         * else is a scan and shouldn't be hit often.
         */
        switch(th_flags_cleaned)
        {
            case R_SYN:
                DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN, "spp_portscan: SYN packet\n"););
                scan |= sSYN;
                break;

            case R_RST:
                /* Nothing.  This is legitimately tearing down a connection. */
                break;

            case R_FIN:
                scan |= sFIN;
                break;

            case (R_SYN | R_FIN):
                scan |= sSYNFIN;
                break;

            case 0:
                scan |= sNULL;
                break;

            case (R_FIN | R_PSH | R_URG):
                scan |= sXMAS;
                break;

            case R_URG:
            case R_PSH:
            case (R_URG | R_FIN):
            case (R_PSH | R_FIN):
            case (R_URG | R_PSH):
                scan |= sVECNA;
                break;

            case (R_SYN | R_FIN | R_PSH | R_URG):
                scan |= sNMAPID;
                break;

            default:
                /*
                 * We assume that anything down here w/out an ACK flag is some
                 * sort of a scan or something.  Anyway, we'll flag it because if
                 * it doesn't have an ACK it should have been only a SYN or RST
                 * and be detected above.
                 */
                scan |= sNOACK;
                break;
        }
    }

    return(scan);
}


void ParsePortscanArgs(u_char * args)
{
    char **toks;
    int numToks;

    struct stat st;

    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,MODNAME ": ParsePortscanArgs(): %s\n", args););

    logLevel = lNONE;

    if(!args)
    {
        FatalError(MODNAME ": ERROR: %s (%d) => portscan configuration format:  address/mask ports seconds logDir sensor_name\n", file_name, file_line);
    }

    /* the '\\' sets the string escape delimiter - MFR */
    /* the sguil mod adds a seventh arg -> sensorName - Bammkkkk */
#ifdef WIN32
    toks = mSplit(args, " ", 7, &numToks, 0);
#else
    toks = mSplit(args, " ", 7, &numToks, '\\');    /* ZDNOTE What does the
                                                     * '\\' do? */
#endif

    /* Went ahead and made all the args mandatory. - Bammkkkk */
    printf("Number of toks: %i\n", numToks);
    if((numToks != 5))
    {
        FatalError(MODNAME ": ERROR: %s (%d) => portscan configuration format:  address/mask ports seconds logdir sensor_name\n", file_name, file_line);
    }

    maxPorts = atoi(toks[1]);
    maxTime.tv_sec = atoi(toks[2]);
    maxTime.tv_usec = 0;

    PortscanParseIP(toks[0]);
    /* ParseIP(toks[0], homeAddr); */

    /* Lots of stuff deleted - Bammkkkk */

        logDirName = toks[3];
        //strncat(logDirName, toks[3], strlen(toks[3]) + 1);
        DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,MODNAME ": logDirName = %s\n", logDirName););
	if(stat(logDirName, &st) < 0)
	{
		FatalError(MODNAME ": Unable to stat directory (%s)\n", logDirName);
	}
	if((!S_ISDIR(st.st_mode) || access(logDirName, W_OK) < 0))
	{
		FatalError(MODNAME ": %s is not a directory or is not writable", logDirName);
	}

        logLevel |= lFILE;

	/* - Bammkkkk
        logFile = fopen(logFileName, "a+");
        if(!logFile)
        {
            perror("fopen");
            FatalError(MODNAME ": logfile open error (%s)\n", logFileName);
        }

	*/

	/* Set the sensor name for the log file - Bammkkkk */
	sensorName = toks[4];
    /* How about some error detecting? :) */
    if(maxPorts == 0 || maxTime.tv_sec == 0)
    {
        FatalError(MODNAME ": ERROR: %s (%d) => portscan configuration format:  address/mask ports seconds logDir sensor_name\n", file_name, file_line);
    }
    /*
     * ZDNOTE Compile time settings.  Obviously needs to become runtime
     * settings.
     */
    /*
     * If you do not want every packet with reserved bits set (which
     * shouldn't happen), just remove the "| sRESERVEDBITS" from the end of
     * this line.  If you do that, you may wish to add a line to detect that
     * in the rules file(s).
     */
    /*
     * ZDNOTE If/when I add this to options, this would be "usfFnxXrvidI"
     * scan detection.
     */
    scansToWatch = ~(sRESERVEDBITS|sUDP);      /* Watch for ALL scans */
    /*
     * scansToWatch = sUDP | sSYN | sFIN | sSYNFIN | sNULL | sXMAS |
     * sFULLXMAS | sRESERVEDBITS | sVECNA | sNOACK | sNMAPID | sSPAU |
     * sINVALIDACK;
     */
    /* can watch all scans but disable some by doing the following */
    /* scansToWatch = ~(sRESERVEDBITS | sNMAPID ); */

    /*
     * ZDNOTE.  I'm a fascist and I want people to use my new feature, so I'm
     * forcing everyone to default to my extended logging.  Mwua-ha-ha-ha!!!
     */
    logLevel |= lEXTENDED;

    /* If you want to log packet contents, uncomment this line. */
    /* logLevel |= lPACKET; */

    /*
     * If you want to change the number of bytes of packet data stored,
     * change this value. This is the size of the payload and does not
     * include the packet header. Set the value to -1 to log the complete
     * packet contents.
     */
    packetLogSize = 100;

    if(pv.use_utc == 1)
    {
        timeFormat = tGMT;
        if(!pv.quiet_flag)
            printf("Using GMT time\n");
    }
    else
    {
        timeFormat = tLOCAL;
        if(!pv.quiet_flag)
            printf("Using LOCAL time\n");
    }
}


void LogScanInfoToSeparateFile(SourceInfo * currentSource)
{
    DestinationInfo *currentDestination;
    ConnectionInfo *currentConnection;
    char *scanType;
    char *reservedBits;
    char *month;
    struct tm *time;
    char sourceAddress[16], destinationAddress[16];
    char outBuf[160];       /* Don't need anywhere near this, but better
                 * safe than sorry. */
    char currentTime[80];
    char logFileName[STD_BUF];
    FILE *logFile;

    /* Open file to log to - Bammkkkk */
    snprintf(logFileName, STD_BUF, "%s/portscan_log.%lu", logDirName, GetMilliseconds());
    logFile = fopen(logFileName, "a");
    if(!logFile)
    {
	    perror("fopen");
	    FatalError(MODNAME ": Unable to open logfile (%s)\n", logFileName);
    }

    memset(sourceAddress, '\0', 16);
    memset(destinationAddress, '\0', 16);

    /*
     * Can't have two inet_ntoa() calls in a single printf because it uses a
     * static buffer.  It's also faster to only do it twice instead of twice
     * for each iteration.
     */
    strncpy(sourceAddress, inet_ntoa(currentSource->saddr), 15);

    for(currentDestination = currentSource->destinationsList; currentDestination;
       currentDestination = currentDestination->nextNode)
    {
        strncpy(destinationAddress, inet_ntoa(currentDestination->daddr), 15);

        for(currentConnection = currentDestination->connectionsList; currentConnection;
           currentConnection = currentConnection->nextNode)
        {
            /*
             * Apparently, through some stroke of genius and/or luck,
             * timeval.tv_sec can be used just like time_t.  Sweet.  And
             * stuff.
             */
            time = (timeFormat == tLOCAL) ? localtime((time_t *) & currentConnection->timestamp.tv_sec) : gmtime(&currentConnection->timestamp.tv_sec);
	    strftime(currentTime, 80, "%F %T", time);

            switch(time->tm_mon)
            {
                case 0:
                    month = "Jan";
                    break;
                case 1:
                    month = "Feb";
                    break;
                case 2:
                    month = "Mar";
                    break;
                case 3:
                    month = "Apr";
                    break;
                case 4:
                    month = "May";
                    break;
                case 5:
                    month = "Jun";
                    break;
                case 6:
                    month = "Jul";
                    break;
                case 7:
                    month = "Aug";
                    break;
                case 8:
                    month = "Sep";
                    break;
                case 9:
                    month = "Oct";
                    break;
                case 10:
                    month = "Nov";
                    break;
                case 11:
                    month = "Dec";
                    break;
                default:
                    month = "MONTH IS INVALID!!";
                    break;
            }

            reservedBits = (currentConnection->scanType & sRESERVEDBITS) ? "RESERVEDBITS" : "";

            DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,"scanType = %x mask = %x result = (%x)\n", currentConnection->scanType, ~sRESERVEDBITS, currentConnection->scanType & ~sRESERVEDBITS););

            switch(currentConnection->scanType & ~sRESERVEDBITS)
            {
                case sUDP:
                    scanType = "UDP";
                    break;
                case sSYN:
                    scanType = "SYN";
                    break;
                case sFIN:
                    scanType = "FIN";
                    break;
                case sSYNFIN:
                    scanType = "SYNFIN";
                    break;
                case sNULL:
                    scanType = "NULL";
                    break;
                case sXMAS:
                    scanType = "XMAS";
                    break;
                case sFULLXMAS:
                    scanType = "FULLXMAS";
                    break;
                case sVECNA:
                    scanType = "VECNA";
                    break;
                case sNOACK:
                    scanType = "NOACK";
                    break;
                case sNMAPID:
                    scanType = "NMAPID";
                    break;
                case sSPAU:
                    scanType = "SPAU";
                    break;
                case sINVALIDACK:
                    scanType = "INVALIDACK";
                    break;
                default:
                    /*
                     * This used to mean I screwed up, but now since any packet
                     * that has reserved bits set is set as a scan it looks bad
                     * if "ERROR" shows up when the packet really has something
                     * bizarre like "2****P**".
                     */

                    DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,"UNKNOWN: scanType = %x (%x)\n", currentConnection->scanType, currentConnection->scanType & ~sRESERVEDBITS););

                    scanType = "UNKNOWN";
                    break;
            }

            /* I have control of all data here, so this should be safe */
	    /*
            sprintf(outBuf, "%s %2d %.2d:%.2d:%.2d %s:%d -> %s:%d %s %s %s\n", month, time->tm_mday,
                    time->tm_hour, time->tm_min, time->tm_sec,
                    sourceAddress, currentConnection->sport, destinationAddress,
                    currentConnection->dport, scanType, currentConnection->tcpFlags, reservedBits);
	    */
	    sprintf(outBuf, "%s|%s|%s|%d|%s|%d|%s %s %s\n", sensorName, currentTime, sourceAddress,
			   currentConnection->sport, destinationAddress, currentConnection->dport,
			   scanType, currentConnection->tcpFlags, reservedBits);
            fwrite(outBuf, strlen(outBuf), 1, logFile);
        }
    }

    /* Now that we're done, flush the buffer to disk. */
    fflush(logFile);
    fclose(logFile);
}


/***** AlertIntermediateInfo() *****
  Log number of scan packets and types to standard alert mechanism.
*/
void AlertIntermediateInfo(SourceInfo * currentSource)
{
    char logMessage[160];
    Event event;

    sprintf(logMessage, 
            MODNAME ": portscan status from %s: %d connections "
            "across %d hosts: TCP(%d), UDP(%d)%s",
            inet_ntoa(currentSource->saddr), 
            currentSource->numberOfConnections, 
            currentSource->numberOfDestinations,
            currentSource->numberOfTCPConnections, 
            currentSource->numberOfUDPConnections,
            (currentSource->stealthScanUsed) ? " STEALTH" : "");

    SetEvent(&event, GENERATOR_SPP_PORTSCAN, 
            PORTSCAN_INTER_INFO, 1, 0, 0, currentSource->event_id);
    CallAlertFuncs(NULL, logMessage, NULL, &event);

    return;
}


void ExtractHeaderInfo(Packet * p, struct in_addr * saddr, 
                       struct in_addr * daddr, u_short * sport, 
                       u_short * dport)
{
    /*
     * This function seems kinda silly now that I don't have to do protocol
     * checks to use the proper protocol headers to get the port, but I think
     * it still makes it easier and I don't have to worry about something
     * changing later.
     */

    *sport = p->sp;
    *dport = p->dp;
    *saddr = p->iph->ip_src;
    *daddr = p->iph->ip_dst;
}


/* Check if packet originated from a machine we have been told to ignore
   SYN and UDP "scans" from, presumably because it's a server.
*/
int IsServer(Packet * p)
{
    ServerNode *currentServer = serverList;

#ifdef DEBUG
    char sourceIP[16], ruleIP[16], ruleNetMask[16];

#endif

    while(currentServer)
    {
        /*
         * Return 1 if the source addr is in the serverlist, 0 if nothing is
         * found.
         */
        if(CheckAddrPort(currentServer->address, 0, 0, p,
                         (ANY_SRC_PORT | currentServer->ignoreFlags), CHECK_SRC))
        {

#ifdef DEBUG
            memset(sourceIP, '\0', 16);
            memset(ruleIP, '\0', 16);
            memset(ruleNetMask, '\0', 16);
            strncpy(sourceIP, inet_ntoa(p->iph->ip_src), 15);
            strncpy(ruleIP, inet_ntoa(*(struct in_addr *) & (currentServer->address->ip_addr)), 14);
            strncpy(ruleNetMask, inet_ntoa(*(struct in_addr *) & (currentServer->address->netmask)), 15);

            printf(MODNAME ": IsServer():  Server %s found in %s/%s!\n", sourceIP, ruleIP, ruleNetMask);
#endif

            return(1);
        }
        currentServer = currentServer->nextNode;
    }

    return(0);
}


void SetupPortscanIgnoreHosts(void)
{
    RegisterPreprocessor("portscan-ignorehosts", PortscanIgnoreHostsInit);
}


void PortscanIgnoreHostsInit(u_char * args)
{
    CreateServerList(args);
}


/* Well, it seems we are ignoring more than just servers now.  We're also
   ignoring SYN and UDP scans from our own networks.  I guess this is okay.
   Most networks have a soft, chewy center, anyway.  Besides, this
   makes the coding easier! ;)
*/
void CreateServerList(u_char * servers)
{
    char **toks;
    int num_toks;
    int num_servers = 0;
    ServerNode *currentServer;
    int i;

#ifdef DEBUG
    char ruleIP[16], ruleNetMask[16];

#endif

    currentServer = NULL;
    serverList = NULL;

    if(servers == NULL)
    {
        FatalError(MODNAME ": ERROR: %s (%d)=> No arguments to portscan-ignorehosts preprocessor!\n", file_name, file_line);
    }
    /* tokenize the argument list */
    toks = mSplit(servers, " ", 31, &num_toks, '\\');

    /* convert the tokens and place them into the server list */
    for(num_servers = 0; num_servers < num_toks; num_servers++)
    {
        if(currentServer != NULL)
        {
            currentServer->nextNode = (ServerNode *) calloc(sizeof(ServerNode), sizeof(char));
            currentServer = currentServer->nextNode;
        }
        else
        {
            currentServer = (ServerNode *) calloc(sizeof(ServerNode), sizeof(char));
            serverList = currentServer;
        }

        DEBUG_WRAP(DebugMessage(DEBUG_PLUGIN,MODNAME ": CreateServerList(): Adding server %s\n", toks[num_servers]););
        /* currentServer->ignoreFlags = 0; */

        PortscanIgnoreParseIP(toks[num_servers], currentServer);
        /* ParseIP(toks[num_servers], &currentServer->address); */

#ifdef DEBUG
        memset(ruleIP, '\0', 16);
        memset(ruleNetMask, '\0', 16);
        strncpy(ruleIP, inet_ntoa(*(struct in_addr *) & currentServer->address->ip_addr), 15);
        strncpy(ruleNetMask, inet_ntoa(*(struct in_addr *) & currentServer->address->netmask), 15);
        printf(MODNAME ": CreateServerList(): Added server %s/%s\n", ruleIP, ruleNetMask);
#endif

        currentServer->nextNode = NULL;
    }

    for(i = 0; i < num_toks; i++)
    {
        free(toks[i]);
    }
}



void PortscanParseIP(char *addr)
{
    char **toks;
    int num_toks;
    int i;
    IpAddrSet *tmp_addr;
    char *tmp;

    if(*addr == '!')
    {
        homeFlags |= EXCEPT_DST_IP;
        addr++;
    }

    if(*addr == '$')
    {
        if((tmp = VarGet(addr + 1)) == NULL)
        {
            FatalError("ERROR %s (%d) => Undefined variable %s\n", file_name, 
                       file_line, addr);
        }
    }
    else
    {
        tmp = addr;
    }

    if (*tmp == '[')
    {
        *(strrchr(tmp, (int)']')) = 0; /* null out the en-bracket */

        toks = mSplit(tmp+1, ",", 128, &num_toks, 0);

        for(i = 0; i < num_toks; i++)
        {
            tmp_addr = PortscanAllocAddrNode();

            ParseIP(toks[i], tmp_addr);
        }

        for(i=0;i<num_toks;i++)
            free(toks[i]);
    } 
    else
    {
        tmp_addr = PortscanAllocAddrNode();
        ParseIP(tmp, tmp_addr);
    }
}


void PortscanIgnoreParseIP(char *addr, ServerNode* server)
{
    char **toks;
    int num_toks;
    int i;
    IpAddrSet *tmp_addr;
    int global_negation_flag;
    char *tmp;

    if(addr == NULL)
    {
        FatalError("ERROR %s(%d) => Undefined address in portscan-ignorehosts directive\n", file_name, file_line);
    }

    if(*addr == '!')
    {
        global_negation_flag = 1;
        addr++;
    }

    if(*addr == '$')
    {
        if((tmp = VarGet(addr + 1)) == NULL)
        {
            FatalError("ERROR %s (%d) => Undefined variable %s\n", file_name, 
                       file_line, addr);
        }
    }
    else
    {
        tmp = addr;
    }

    if (*tmp == '[')
    {
        *(strrchr(tmp, (int)']')) = 0; /* null out the en-bracket */

        toks = mSplit(tmp+1, ",", 128, &num_toks, 0);

        for(i = 0; i < num_toks; i++)
        {
            tmp_addr = PortscanIgnoreAllocAddrNode(server);

            ParseIP(toks[i], tmp_addr);
        }

        for(i=0;i<num_toks;i++)
            free(toks[i]);
    } 
    else
    {
        tmp_addr = PortscanIgnoreAllocAddrNode(server);
        
        ParseIP(tmp, tmp_addr);
    }
}

IpAddrSet *PortscanAllocAddrNode()
{
    IpAddrSet *idx;     /* IP struct indexing pointer */

    if(homeAddr == NULL)
    {
        homeAddr = (IpAddrSet *) calloc(sizeof(IpAddrSet), sizeof(char));

        if(homeAddr == NULL)
        {
            FatalError("[!] ERROR: Unable to allocate space for portscan IP addr\n");
        }

        return homeAddr;
    }

    idx = homeAddr;

    while(idx->next != NULL)
    {
        idx = idx->next;
    }

    idx->next = (IpAddrSet *) calloc(sizeof(IpAddrSet), sizeof(char));

    idx = idx->next;

    if(idx == NULL)
    {
        FatalError("[!] ERROR: Unable to allocate space for portscan IP address\n");
    }

    return idx;
}



IpAddrSet *PortscanIgnoreAllocAddrNode(ServerNode * server)
{
    IpAddrSet *idx;     /* IP struct indexing pointer */

    if(server->address == NULL)
    {
        server->address = (IpAddrSet *) calloc(sizeof(IpAddrSet), sizeof(char));

        if(server->address == NULL)
        {
            FatalError("[!] ERROR: Unable to allocate space for portscan IP addr\n");
        }
        return server->address;
    }
    idx = server->address;

    while(idx->next != NULL)
    {
        idx = idx->next;
    }

    idx->next = (IpAddrSet *) calloc(sizeof(IpAddrSet), sizeof(char));

    idx = idx->next;

    if(idx == NULL)
    {
        FatalError("[!] ERROR: Unable to allocate space for portscan IP address\n");
    }
    return idx;
}
