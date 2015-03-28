################################################################################
# THIS SCRIPT DETECTS FAHCORE USAGE AND THEN GENERATES AN RSS FEED WITH UPDATES
# THIS SCRIPT IS INTENDED TO NOTIFY FAH SCIENTISTS OF VSP-FAH AVAILABILITY
################################################################################
#!/bin/bash

IFS=$'\n' #SEPARATE FIELDS BY NEWLINE
RSS=/home/server/status/vsp-fah-status.xml #PATH TO RSS FEED
LOG=/home/server/log.txt #PATH TO FAHCORE LOG
GPULIST=/home/server/status/GPUs.txt #LIST OF CURRENTLY INSTALLED GPUS ORDERED BY SLOT NUMBER()
CORE=`ps cax | grep FahCore | awk '{ print $5 }'` #CORE STATUS
PROJECT=`grep Project $LOG | tail -1 | awk '{for(i=2;i<NF;i++)printf "%s",$i OFS; if (NF) printf "%s",$NF; printf ORS}'` #CURRENT RUNNING PROJECT
DATE=`date -R` #CURRENT DATE
PREV=`grep -m 5 -A6 "<item>" $RSS` #PREVIOUS 5 STATUS UPDATES (NECESSARY FOR IFTTT TO NOTIFY THE SLACK)
PREVGPU=`grep -m 1 -A6 "<item>" $RSS | grep description | cut -d">" -f2 | awk '{ print $1 }'` #MOST PREVIOUS GPU STATUS
PREVGPU=`grep $PREVGPU $GPULIST` #CHECK TO SEE IF PREVIOUS GPU IS IN LIST (EMPTY IF NO GPU WAS IN USE)

#CHECK IF THERE WAS A PROJECT RUNNING BEFORE
if [ `grep -m 1 -A6 "<item>" $RSS | grep description | awk '{print NF}'` -gt 4 ]; then 
	PREVPROJECT=`grep -m 1 -A6 "<item>" $RSS | grep description | awk '{for(i=NF-6;i< NF;i++)printf "%s",$i OFS; if (NF) printf "%s",$NF; printf ORS}' | cut -d"<" -f1` || ""
else
	PREVPROJECT=""
fi

STATUS=`grep -A1 item $RSS | grep title | head -1 | grep "not"` #GET PREVIOUS STATUS

#IF FAHCORE IS RUNNING OR IT'S NOT NOW BUT WAS DURING THE LAST CHECK THEN EXECUTE
if [ -n "$CORE" ] || [ -z "$CORE" -a -z "$STATUS" ]; then
	GPU=$((`grep READY $LOG | cut -d":" -f6 | head -1`+1)) #RETRIEVE GPU SLOT
	GPU=`sed -n "${GPU}p" $GPULIST` #GET GPU NAME
	#IF THE WAS NO GPU RUNNING BEFORE OR A DIFFERENT GPU WAS RUNNING OR A DIFFERENT PROJECT WAS RUNNING THE EXECUTE
	if [ -z "$PREVGPU" ] || [ "$GPU" != "$PREVGPU" ] || [ "$PROJECT" != "$PREVPROJECT" ]; then
		#GENERATE NEW FEED (KIND OF MESSY)
		echo '<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">' > $RSS
		echo -e "\t<channel>" >> $RSS
		echo -e "\t\t<title>VSP-FAH - Status</title>" >> $RSS
		echo -e "\t\t<atom10:link xmlns:atom10='http://www.w3.org/2005/Atom' rel='self' type='application/rss+xml' href='http://stanford.edu/~cxh/vsp-fah-status.xml'/>" >> $RSS
		echo -e "\t\t<lastBuildDate>$DATE</lastBuildDate>" >> $RSS
		echo -e "\t\t<item>" >> $RSS
		if [ -n "$CORE" ]; then
			echo -e "\t\t\t<title>vsp-fah is currently in use</title>" >> $RSS
			echo -e "\t\t\t<description>$GPU is running project $PROJECT</description>" >> $RSS
		else
			echo -e "\t\t\t<title>vsp-fah is currently not in use</title>" >> $RSS
			echo -e "\t\t\t<description>Feel free to benchmark</description>" >> $RSS
		fi

		echo -e "\t\t\t<link>vsp-fah.stanford.edu</link>" >> $RSS
		echo -e "\t\t\t<guid isPermaLink='false'>vspfah$RANDOM</guid>" >> $RSS
		echo -e "\t\t\t<pubDate>$DATE</pubDate>" >> $RSS
		echo -e "\t\t</item>" >> $RSS
		for i in $PREV; do
			echo $i >> $RSS
		done
		echo -e "\t</channel>" >> $RSS
		echo -e "</rss>" >> $RSS

		scp $RSS cxh@corn.stanford.edu:~/WWW/ #SEND RSS FEED TO CORN
	fi
fi
