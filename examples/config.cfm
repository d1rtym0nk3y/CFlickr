<cfscript>
apikey = "your api key here";
secret = "your secret here";
token = "get this by authenticating";
userid = "get this by authenticating";
</cfscript>

<!--- This is just to include my config during development, you can ignore it --->
<cftry>
	<cfinclude template="dev_config.cfm">
	<cfcatch type="Any"></cfcatch>
</cftry>

<cfscript>
cflickr = createobject("component", "cfc.CFlickr").init(apikey, secret);
</cfscript>