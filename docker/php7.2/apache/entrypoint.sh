#!/bin/bash

##############################################
# Configuration files
##############################################
echo -e "\e[32mStart creating configuration files\e[0m"
filename=config/autoload/db.local.php
if [ ! -e $filename ]; then
	{
		echo "<?php"
		echo "return ["
		echo "    'dbadapter' => ["
		echo "        'username' => '${PASSWORDCOCKPIT_DATABASE_USERNAME}',"
		echo "        'password' => '${PASSWORDCOCKPIT_DATABASE_PASSWORD}'," 
		echo "        'hostname' => '${PASSWORDCOCKPIT_DATABASE_HOSTNAME}',"
		echo "        'database' => '${PASSWORDCOCKPIT_DATABASE_DATABASE}'"
		echo "    ]"
		echo "];"
	} >> $filename
fi

filename=config/autoload/doctrine.local.php
if [ ! -e $filename ]; then
	{
		echo "<?php"
		echo "return ["
		echo "    'doctrine' => ["
		echo "        'connection' => ["
		echo "            'orm_default' => [" 
		echo "                'params' => ["
		echo "                    'url' =>"
		echo "                        'mysql://${PASSWORDCOCKPIT_DATABASE_USERNAME}:${PASSWORDCOCKPIT_DATABASE_PASSWORD}@${PASSWORDCOCKPIT_DATABASE_HOSTNAME}/${PASSWORDCOCKPIT_DATABASE_DATABASE}'"
		echo "                ]"
		echo "            ]"
		echo "        ]"
		echo "    ]"
		echo "];"
	} >> $filename
fi

filename=config/autoload/crypt.local.php
if [ ! -e $filename ]; then
	{
		echo "<?php"
		echo "return ["
		echo "    'block_cipher' => ["
		echo "        'key' => '${PASSWORDCOCKPIT_BLOCK_CIPHER_KEY}'"
		echo "    ]" 
		echo "];"
	} >> $filename
fi

if [ "${PASSWORDCOCKPIT_AUTHENTICATION_TYPE}" == "ldap" ]; then
	filename=config/autoload/authentication.local.php
	if [ ! -e $filename ]; then
		{
			echo "<?php"
			echo "return ["
			echo "    'authentication' => ["
			echo "        'secret_key' => '${PASSWORDCOCKPIT_AUTHENTICATION_SECRET_KEY}'"
			echo "    ]," 
			echo "    'dependencies' => ["
			echo "        'factories' => ["
			echo "            Zend\Authentication\Adapter\AdapterInterface::class =>"
			echo "                Authentication\Api\V1\Factory\Adapter\LdapAdapterFactory::class"
			echo "        ]"
			echo "    ]"
			echo "];"
		} >> $filename
	fi

	filename=config/autoload/ldap.local.php
	if [ ! -e $filename ]; then
		{
			echo "<?php"
			echo "return ["
			echo "    'ldap' => [["
			echo "        'host' => '${PASSWORDCOCKPIT_LDAP_HOST}',"
			echo "        'port' => ${PASSWORDCOCKPIT_LDAP_PORT},"
			echo "        'username' => '${PASSWORDCOCKPIT_LDAP_USERNAME}',"
			echo "        'password' => '${PASSWORDCOCKPIT_LDAP_PASSWORD}',"
			echo "        'baseDn' => '${PASSWORDCOCKPIT_LDAP_BASEDN}',"
			echo "        'accountFilterFormat' => '${PASSWORDCOCKPIT_LDAP_ACCOUNTFILTERFORMAT}',"
			echo "        'bindRequiresDn' => ${PASSWORDCOCKPIT_LDAP_BINDREQUIRESDN}"
			echo "    ]]" 
			echo "];"
		} >> $filename
	fi
elif [ "${PASSWORDCOCKPIT_AUTHENTICATION_TYPE}" == "password" ]; then
	filename=config/autoload/authentication.local.php
	if [ ! -e $filename ]; then
		{
			echo "<?php"
			echo "return ["
			echo "    'authentication' => ["
			echo "        'secret_key' => '${PASSWORDCOCKPIT_AUTHENTICATION_SECRET_KEY}'"
			echo "    ]" 
			echo "];"
		} >> $filename
	fi
fi

filename=config/constants.local.php
if [ ! -e $filename ]; then
	{
		echo "<?php"
		echo "define('SWAGGER_API_HOST', '${PASSWORDCOCKPIT_BASEHOST}');"
	} >> $filename
fi
echo -e "\e[32mConfiguration files created\e[0m"


##############################################
# Update frontend files
##############################################
echo -e "\e[32mStart updating frontend files\e[0m"
sed -ri -e 's!PASSWORDCOCKPIT_BASEHOST!'${PASSWORDCOCKPIT_BASEHOST}'!g' public/index.html
sed -ri -e 's!PASSWORDCOCKPIT_BASEHOST!'${PASSWORDCOCKPIT_BASEHOST}'!g' public/assets/*.*
echo -e "\e[32mFrontend files updated\e[0m"


##############################################
# Database
##############################################
echo -e "\e[31Check database connection\e[0m"
max_retries=10
try=0

while [ "$try" -lt "$max_retries" ]
do
	connection=$(vendor/bin/doctrine dbal:run-sql "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${PASSWORDCOCKPIT_DATABASE_DATABASE}'")
	# schema_name is unset or set to the empty string so connecting problem
	if [ -z "${connection}" ]; then
		echo -e "\e[31mRetrying connection...\e[0m"
		try=$((try+1))
		sleep 3s
		continue
	fi
	schema_exist=$(echo $connection | grep array | awk -F"[()]" '{print $2}')
	# connection ok and schema exist
	if [ "$schema_exist" == "1" ]; then
		echo -e "\e[32mConnection ok\e[0m"
		echo -e "\e[32mSchema already exist\e[0m"
		# Tables exists
		number_of_tables=$(vendor/bin/doctrine dbal:run-sql "SELECT count(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '${PASSWORDCOCKPIT_DATABASE_DATABASE}'" | grep string | awk -F\" '{ print $2 }')
		if [ "$number_of_tables" == "0" ]; then
			# Create the tables and popolate it
			vendor/bin/doctrine orm:schema-tool:create
			vendor/bin/doctrine orm:generate-proxies
			echo -e "\e[32mDatabase created\e[0m"
			vendor/bin/doctrine dbal:import database/create-production-environment.sql
			echo -e "\e[32mProduction data installed\e[0m"
		else
			# Update scripts
			echo -e "\e[32mNo updates to be carried out\e[0m"
		fi
		break
	fi
	# connection ok and schema not exist: error
	if [ "$schema_exist" == "0" ]; then
		echo -e "\e[32mConnection ok\e[0m"
		echo -e "\e[31mSchema not exist\e[0m"
		echo -e "\e[31mInstalling failed!\e[0m"
		exit 1
		break
	fi
done
# Connection error
if [ "$try" -gt "$max_retries" ]; then
	echo -e "\e[31mInstalling failed!\e[0m"
	exit 1
fi

echo -e "\e[32mPasswordcockpit ready\e[0m"

exec "$@"