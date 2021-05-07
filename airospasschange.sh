########################################################################################
#!/bin/bash
#AirOS Password Changes
#Matthew Holder - matthew@current-networks.com
#https://www.current-networks.com
########################################################################################

##########
#User Variables
##########
USER="ubnt"
PASS="donttellanyone"
NEWPASS="donttellanyone"
DEVICELIST=(
	192.168.1.20 
	192.168.1.21 
	192.168.1.22
)



##########
#OTHER VARIABLES
##########
TIMESTAMP=$(date +"%m-%d-%Y at %H.%M.%S %p") 
DEBUG=0
MAXDEBUG=0
LOGNAME="AirOS_PassChange - ${TIMESTAMP}.log"
DEBUGLOGNAME="AirOS_PassChangeDebug - ${TIMESTAMP}.log"

##########
#COMMANDS AS VARIABLES
##########

#AIROSCOMMAND TO CREATE AN MD5 HASH W/ SALT PASSWORD
CHANGEPASS="passwd -a md5crypt\r"

#COMMAND TO COPY SYSTEM.CFG TO NEW WITHOUT PASSWORD AND THEN OVERWRITE SYSTEM CONFIG 
COPYMOVECONFIG="grep -F -v users.1.password= /tmp/system.cfg > /tmp/system.cfg.new && mv /tmp/system.cfg.new /tmp/system.cfg \r"

#COMMAND TO COPY UNIX USER PASSWORD INTO SYSTEM.CFG
COPYPASSWORD="echo users.1.password=\`grep $USER /etc/passwd | cut -d: -f2 | cut -d: -f1\` >> /tmp/system.cfg \r"

#AIROS COMMAND TO SAVE THE NEW CONFIG
SAVECONFIG="cfgmtd -f /tmp/system.cfg -w \r"

##########
#LOG HOUSEKEEPING
##########

touch "$LOGNAME"
echo -e "\n$(date) - Starting Password Change on Hosts" >> "$LOGNAME"
echo "$(date) - Starting Password Change on Hosts"

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
		#EXPECT SCRIPT TO DO THE WROK
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
					"Password for $USER changed by $USER" { }

					#FAIL BECAUSE THE PASSWORD DIDNT CHANGE OR SOMETHING WENT WRONG
					timeout {
						set output "$(date) - Host $IPADDR - Password Changed Failed - Did Not Save"
						send_user "\$output \n"
						puts \$log "\$output"
						close \$log
						exit 1
					}
				}

				#WAIT FOR PROMPT
				#expect "*#" {
				#	send -- "grep $USER /etc/passwd | cut -d: -f2 | cut -d: -f1 \r"

					#sleep 3
					
					expect "*#" {
						#set output "\$expect_out(0,string)"
						#set UNIXHASH ""
						#set result [regexp {\$(.*), 'm'} \$output ignore UNIXHASH]

						#puts "\n\n--UNIXHASH--> \$UNIXHASH <--UNIXHASH--\n"

						#WAIT FOR PROMPT
						expect "*#"
						#SEND COMMANDS TO COPY OLD CONFIG TO NEW CONFIG WITHOUT PASSWORD 
						#DELETE OLD CONFIG, MOVE NEW CONFIG CORRECT LOCATION
						send -- "$COPYMOVECONFIG"

						#WAIT FOR PROMPT
						expect "*#"

						#SEND COMMANDS TO COPY THE UNIX USER PASSWORD TO THE CONFIG FILE
						send -- "$COPYPASSWORD"

						#WAIT FOR PROMPT
						expect "*#"

						#SEND COMMANDS TO INVOKE UBNT SAVE CONFIG APPLICATION
						send -- "$SAVECONFIG"

						#WAIT FOR PROMPT
						expect "*#"

						#EXIT THE SSH SESSION
						send -- "exit\r"

						#SEND LOG INFO FOR SUCCESS
						set output "$(date) - Host $IPADDR - Success"
						send_user "\$output \n"
						puts \$log "\$output"
						close \$log
					}

				#}

		##########
		#END EXPECT SCRIPT
		#BEGINNING AND END CANT HAVE TAB FORMATTING
		##########				
EOF
	#END FOR LOOP
	done

##########
#SCRIPT COMPLETE LOGGING
##########
if [ $DEBUG == 1 ]; then
	echo -e "\n$(date) - Script Complete" >> "$DEBUGLOGNAME"
fi
echo "$(date) - Script Complete" >> "$LOGNAME"
echo "$(date) - Script Complete" 