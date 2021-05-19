########################################################################################
#!/bin/bash
# AirOS Password Changes
# Matthew Holder - matthew@current-networks.com
# https://www.current-networks.com
########################################################################################

##########
#VARIABLES CHANGE AT OWN RISK
##########
TIMESTAMP=$(date +"%m-%d-%Y at %H.%M.%S %p") 
DEBUG=1
MAXDEBUG=0
LOGDIRECTORY="$HOME/Documents/AirOS_PassChange/Logs/"
LOGFILENAME="AirOS_PassChange - ${TIMESTAMP}.log"
DEBUGFILENAME="AirOS_PassChangeDebug - ${TIMESTAMP}.log"
LOGNAME=$LOGDIRECTORY$LOGFILENAME
DEBUGLOGNAME=$LOGDIRECTORY$DEBUGFILENAME
IPLISTFILEDIRECTORY="$HOME/Documents/AirOS_PassChange/ActiveFiles"
IPLISTFILENAME=
USER=
PASS=
NEWUSER=
NEWPASS=
CHANGEUSER=1

#FIRST RUN
if [ ! -d "$IPLISTFILEDIRECTORY" ]; then
	mkdir -p ${LOGDIRECTORY} #~/Documents/AirOS_PassChange/Logs
	mkdir -p ${IPLISTFILEDIRECTORY} #~/Documents/AirOS_PassChange/ActiveFiles
	touch "$IPLISTFILEDIRECTORY/DeviceAndPassList1.txt"
	exit
fi

##########
#LOG HOUSEKEEPING
##########
touch "$LOGNAME"
echo -e "\n$(date) - Starting Password Change on Hosts" >> "$LOGNAME"
echo "$(date) - Starting Password Change on Hosts"

##########
#SETUP VARIABLES
##########


IPLISTFILES=($(find -E $IPLISTFILEDIRECTORY -type f -name "*.txt"))

for IPLISTFILENAME in ${IPLISTFILES[@]}
do 
	echo -e "$(date) - Using File $IPLISTFILES " >> "$LOGNAME"
	if [ $DEBUG == 1 ]; then 
		echo -e "\n -----\n Using File $IPLISTFILES " >> "$DEBUGLOGNAME"
	fi

	linenumber=0
	while IFS= read -r line || [[ -n "$line" ]]; do
		let "linenumber+=1"
		if [ $linenumber -gt 4 ]
			then
				DEVICELIST+=("$line")
		elif [ $linenumber == 1 ]
			then
				USER="$line"
		elif [ $linenumber == 2 ] 
			then
				PASS="$line"
		elif [ $linenumber == 3 ]
			then
				NEWUSER="$line"
		elif [ $linenumber == 4 ]
			then
				NEWPASS="$line"
		fi
	done <$IPLISTFILENAME

	##########
	#COMMANDS AS VARIABLES
	##########

	#AIROSCOMMAND TO CREATE AN MD5 HASH W/ SALT PASSWORD
	CHANGEPASS="passwd -a md5crypt\r"


	if [ $CHANGEUSER == 1 ]; then 
		#REMOVE USERNAME AND PASSWORD FROM CONFIG AND COPY TO TEMP CONFIG
		COPYMOVECONFIG="grep -F -v users.1.name= /tmp/system.cfg | grep -F -v users.1.password= > /tmp/system.cfg.new && mv /tmp/system.cfg.new /tmp/system.cfg \r"
	else 
		#COMMAND TO COPY SYSTEM.CFG TO NEW WITHOUT PASSWORD AND THEN OVERWRITE SYSTEM CONFIG 
		COPYMOVECONFIG="grep -F -v users.1.password= /tmp/system.cfg > /tmp/system.cfg.new && mv /tmp/system.cfg.new /tmp/system.cfg \r"
	fi

	COPYPASSWORD="echo users.1.password=\`grep $USER /etc/passwd | cut -d: -f2 | cut -d: -f1\` >> /tmp/system.cfg \r"
	COPYUSER="echo users.1.name=$NEWUSER >> /tmp/system.cfg \r"


	#AIROS COMMAND TO SAVE THE NEW CONFIG
	SAVECONFIG="cfgmtd -f /tmp/system.cfg -w \r"

	#SOFT RESTART 
	SOFTRESTART="/usr/etc/rc.d/rc.softrestart save \r \r"

	if [ $DEBUG == 1 ]; then
		echo -e "\n$(date) - Starting Password Change on Hosts" >> "$DEBUGLOGNAME"
	fi

	#LOOP THROUGH ALL ADDRESSES LISTED IN DEVICELIST ARRAY AND ATTEMPT TO SSH / CHANGE PASSWORDS
	for IPADDR in ${DEVICELIST[@]}
		do
			if [ $DEBUG == 1 ]; then
				echo -e "\n---\n" >> "$DEBUGLOGNAME"
			fi

			echo "$(date) - Trying Host - $IPADDR" >> "$LOGNAME"

##########
#EXPECT SCRIPT TO DO THE WORK
#BEGINING AND END CANT HAVE TAB FORMATTING
##########
/usr/bin/expect << EOF

			#SET EXPECT LOGGING
			log_user $DEBUG

			if { $DEBUG == 1 } {
				log_file "$DEBUGLOGNAME"
			}
			set log [open "$LOGNAME" a]

			#ATTEMPT TO CONNECT TO HOST
			send_user "$(date) - Trying Host $IPADDR\n"
			spawn ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $USER@$IPADDR 

			expect {
				"password:" {}

				#FAIL IF CANT CONNECT
				timeout { 
					set output "$(date) - Host $IPADDR - Could Not Connect"
					send_user "\$output \n"
					puts \$log "\$output" 
					close \$log
					exit 1
				}
			}
			#SEND PASSWORD TO HOST IF CONNECTED
			send -- "$PASS\r"
			
			#WAIT FOR RESPONSE TO PASSWORD AND PROMPT
			expect {
				"*#" {}

				#FAIL IF PASSWORD OR USERNAME WAS BAD, NEVER GOT PROMPT
				timeout {
					set output "$(date) - Host $IPADDR - Invalid Username or Password"
					send_user "\$output \n"
					puts \$log "\$output" 
					close \$log
					exit 1
				}
			}

			#SEND COMMANDS TO CHANGE PASSWORD
			send -- "$CHANGEPASS"

			#WAIT FOR NEW PASSWORD PROMPT
			expect "New password:"

			#SEND NEW PASSWORD
			send -- "$NEWPASS\r"

			#WAIT FOR SECOND PASSWORD PROMPT
			expect "Retype password:"

			#SEND NEW PASSWORD AGAIN
			send -- "$NEWPASS\r"

			#WAIT FOR COMFIRMATION OF PASSWORD CHANGE
			expect {
				"Password for $USER changed by $USER" {}

				#FAIL BECAUSE THE PASSWORD DIDNT CHANGE OR SOMETHING WENT WRONG
				timeout {
					set output "$(date) - Host $IPADDR - Password Changed Failed - Did Not Save"
					send_user "\$output \n"
					puts \$log "\$output"
					close \$log
					exit 1
				}
			}

			expect "*#"

			send -- "$COPYMOVECONFIG"

			#WAIT FOR PROMPT
			expect "*#"

			#SEND COMMANDS TO COPY THE UNIX USER PASSWORD TO THE CONFIG FILE
			if { $CHANGEUSER == 1 } {
				send -- "$COPYUSER"
				expect "*#"
			} 
			send -- "$COPYPASSWORD"	
			

			#WAIT FOR PROMPT
			#expect "*#"

			#SEND COMMAND TO COPY CONFIG FILE 
			#send -- "$COPYMOVECONFIGUSER"

			#WAIT FOR PROMPT
			#expect "*#"

			#SEND INSERT USERNAME
			#send -- "$COPYUSERTOFILE"

			#WAIT FOR PROMPT
			expect "*#"
			
			send -- "cat /tmp/system.cfg | grep users.1 \r"

			expect "*#" 

			#SEND COMMAND TO SAVE CONFIG
			send -- "$SAVECONFIG"

			#WAIT FOR PROMPT
			expect "*#"

			#SEND COMMANDS TO SOFT RESTART
			send -- "$SOFTRESTART"

			#WAIT FOR PROMPT

			expect "*#" 

			#EXIT THE SSH SESSION
			send -- "exit\r"

			#SEND LOG INFO FOR SUCCESS
			set output "$(date) - Host $IPADDR - Success"
			send_user "\r\$output \n"
			puts \$log "\$output"
			close \$log


##########
#END EXPECT SCRIPT
#BEGINNING AND END CANT HAVE TAB FORMATTING
##########				
EOF
	#END IP LIST LOOP
	done
	echo -e "$(date) - Completed File $IPLISTFILES " >> "$LOGNAME"
	if [ $DEBUG == 1 ]; then 
		echo -e "Completed File $IPLISTFILES \n ----- \n" >> "$DEBUGLOGNAME"
	fi	
#END FILE LOOP
done

##########
#SCRIPT COMPLETE LOGGING
##########
if [ $DEBUG == 1 ]; then
	echo -e "\n$(date) - Script Complete" >> "$DEBUGLOGNAME"
fi
echo "$(date) - Script Complete" >> "$LOGNAME"
echo "$(date) - Script Complete" 