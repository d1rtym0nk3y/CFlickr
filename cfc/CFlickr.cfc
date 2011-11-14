<!---
LICENSE INFORMATION:

Copyright 2010, Chris Blackwell

Licensed under the Apache License, Version 2.0 (the "License"); you may not 
use this file except in compliance with the License. 

You may obtain a copy of the License at 

	http://www.apache.org/licenses/LICENSE-2.0 
	
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
CONDITIONS OF ANY KIND, either express or implied. See the License for the 
specific language governing permissions and limitations under the License.
--->
<cfcomponent name="CFlickr" output="false">

	<cfscript>
    variables.api_key = "";
    variables.secret = "";
	variables.token = "";
	variables.cache = "";
	variables.urls = {
	    rest = 'http://api.flickr.com/services/rest/',
	    upload = 'http://api.flickr.com/services/upload/',	
	    replace = 'http://api.flickr.com/services/replace/',	
		auth = 'http://www.flickr.com/services/auth/'
	};
	
	</cfscript>
	
<!--- CONSTRUCTOR --->
	<cffunction name="init" access="public" output="false" returntype="any">
		<cfargument name="api_key" type="string" required="true" />
		<cfargument name="secret" type="string" default="" />
		<cfargument name="cache" type="any" />
		<cfset variables.api_key = arguments.api_key />
		<cfset variables.secret = arguments.secret />
		<cfif structKeyExists(arguments, "cache")>
			<cfset variables.cache = arguments.cache />
		</cfif>
		<cfreturn this />		
	</cffunction>

<!--- PUBLIC METHODS --->
	<cffunction name="onMissingMethod" access="public" output="false" returntype="any">
		<cfargument name="missingMethodArguments" />
		<cfargument name="missingMethodName" />
		<cfset var method = lcase(replace(arguments.missingMethodName, "_", ".", "all")) />
		<cfif left(method, 7) IS NOT "flickr.">
			<cfset method = "flickr." & method />
		</cfif>
		<cfreturn addSuccessResult(post(method, arguments.missingMethodArguments)) />
	</cffunction>

	<cffunction name="getPhotoUrl" access="public" output="false" returntype="string">
		<cfargument name="photo" type="struct" required="yes">
		<cfargument name="size" type="string" required="no" default="" 
			hint="Use flickr's very odd size keys - o=original, s=smallsquare, m=small, t=thumbnail, b=large, and empty string is medium">
		<cfset var format = "jpg">
		<cfset var secret = arguments.photo.secret>
		<cfset var farm = arguments.photo.farm>
		<cfset var srvr = arguments.photo.server>
		<!--- 
		if the photo struct contains a key "primary" then its a photoset object and we'll
		assume you're after the photo url for the sets primary photo 
		--->
		<cfset var id = structKeyExists(arguments.photo, "primary") ? arguments.photo.primary : arguments.photo.id>
		<cfset arguments.size = lcase(arguments.size)>
		<cfif arguments.size EQ "o">
			<cftry>
				<cfset format = arguments.photo.originalformat>
				<cfset secret = arguments.photo.originalsecret>
				<cfcatch>
				</cfcatch>
			</cftry>
		</cfif>
		<cfif len(arguments.size)>
			<cfset arguments.size = "_" & arguments.size>
		</cfif>
		<cfreturn "http://farm#farm#.static.flickr.com/#srvr#/#id#_#secret##arguments.size#.#format#">
	</cffunction>	

	<cffunction name="getAuthUrl" access="public" output="false" returntype="string">
		<cfargument name="perms" type="string" required="yes" hint="The permission you are requesting, read, write or delete.">
		<cfargument name="frob" type="string" required="no" hint="A frob.">
		<cfset var host = variables.urls.auth & "?">
		<cfset var sig = "">
		<cfset arguments.api_key = variables.api_key>
		<cfset arguments.api_sig = createApiSig(arguments)>
		<cfscript>
		for(key in arguments) {
			if(len(arguments[key])) host = host & lcase(key) & "=" & arguments[key] & "&";
		}
		</cfscript>
		
		<cfreturn host>
	</cffunction>	

	<cffunction name="uploadPhoto" access="public" output="false" returntype="any" hint="Upload a photo to Flickr">
		<cfargument name="photo" type="any" required="yes" hint="Absolute path to an image file to upload">
		<cfargument name="title" type="any" required="no" hint="The title of the photo. ">
		<cfargument name="description" type="any" required="no" hint="A description of the photo. May contain some limited HTML.">
		<cfargument name="tags" type="any" required="no" hint="A space-seperated list of tags to apply to the photo. ">
		<cfargument name="is_public" type="any" required="no" hint="Set to false for no, true for yes. Specifies who can view the photo. ">
		<cfargument name="is_friend" type="any" required="no" hint="Set to false for no, true for yes. Specifies who can view the photo. ">
		<cfargument name="is_family" type="any" required="no" hint="Set to false for no, true for yes. Specifies who can view the photo. ">
		<cfargument name="async" type="any" required="no" default="0" hint="If true will return an upload ticket, if false will return the photoid">
		<cfset var resp = "" />
		<cfset var ret = {
			"stat" = "fail",
			"cached" = false,
			"params" = arguments
		} />
		<cfscript>
		if(structKeyExists(arguments, "is_public")) {
			if(arguments.is_public) arguments.is_public = 1;
			else arguments.is_public = 0;
		}
		if(structKeyExists(arguments, "is_friend")) {
			if(arguments.is_friend) arguments.is_friend = 1;
			else arguments.is_friend = 0;
		}
		if(structKeyExists(arguments, "is_family")) {
			if(arguments.is_family) arguments.is_family = 1;
			else arguments.is_family = 0;
		}
		</cfscript>


		<cfset resp = upload_post(params=arguments, url=variables.urls.upload) />

		<cfset ret["stat"] = resp.rsp.xmlattributes.stat />
		<cfif ret.stat IS "ok">
			<cfif arguments.async>
				<cfset ret["ticketid"] = resp.rsp.ticketid.xmltext />
			<cfelse>
				<cfset ret["photoid"] = resp.rsp.photoid.xmltext />
			</cfif>
		<cfelse>
			<cfset ret["code"] = resp.rsp.err.xmlattributes.code />
			<cfset ret["msg"] = resp.rsp.err.xmlattributes.msg />
		</cfif>
		
		<cfreturn addSuccessResult(ret) />
	</cffunction>
	
	<cffunction name="replacePhoto" access="public" output="true" returntype="any" hint="Replace a photo with a new image">
		<cfargument name="photo"  type="any" required="yes" hint="Absolute path to an image file to upload">
		<cfargument name="photo_id"  type="any" required="yes" hint="The ID of the photo to replace">
		<cfargument name="async"  type="any" required="no" default="0" hint="If true will return a upload ticket, if false will return the photoid">
		<cfset var resp = "" />
		<cfset var ret = {
			"stat" = "fail",
			"cached" = false,
			"params" = arguments
		} />
		<cfset resp = upload_post(params=arguments, url=variables.urls.replace) />
		<cfset ret["stat"] = resp.rsp.xmlattributes.stat />
		<cfif ret.stat IS "ok">
			<cfif arguments.async>
				<cfset ret["ticketid"] = resp.rsp.ticketid.xmltext />
			<cfelse>
				<cfset ret["photoid"] = resp.rsp.photoid.xmltext />
				<cfset ret["originalsecret"] = resp.rsp.photoid.xmlattributes.originalsecret />
				<cfset ret["secret"] = resp.rsp.photoid.xmlattributes.secret />
			</cfif>
		<cfelse>
			<cfset ret["code"] = resp.rsp.err.xmlattributes.code />
			<cfset ret["msg"] = resp.rsp.err.xmlattributes.msg />
		</cfif>
		
		<cfreturn addSuccessResult(ret) />
	</cffunction>
	

<!--- PRIVATE METHODS --->
	<cffunction name="post" access="private" output="false" returntype="any">
		<cfargument name="method" type="string" required="true" />
		<cfargument name="params" type="struct" default="#structnew()#" />
		<cfscript>
		var httpreq = "";
		var result = "";
		// required params for all calls
		params.method = arguments.method;
		params.api_key = variables.api_key;
		// we want a simple json response with no callback wrapper function 
		params.format="json";
		params.nojsoncallback=1;
		// if theres a secret, sign the request
		if(len(variables.secret)) {
			params.api_sig = createApiSig(params);
		}
		</cfscript>
		
		<!--- see if its in the cache --->
		<cfif isObject(variables.cache) AND variables.cache.existsInCache(params)>
			<!--- if the cache is an object cache just return the object --->
			<cfif variables.cache.isObjectCache()>
				<!--- return a duplicate so changes made outside don't corrupt the cached version --->
				<cfset result = duplicate(variables.cache.getFromCache(params)) /> 
			<!--- otherwise get the json string and desrialize it and return that --->
			<cfelse>
				<cfset result = fixJsonResponse(deserializeJson(cache.getFromCache(params))) />
			</cfif>
			<cfset result["cached"] = true />
		<cfelse>
			<cfhttp url="#variables.urls.rest#" method="post" result="httpreq">
				<cfloop collection="#params#" item="i">
					<cfhttpparam name="#lcase(i)#" type="formfield" value="#params[i]#">
				</cfloop>
			</cfhttp>
			
			<!--- store the response in the cache --->
			<cfset cacheResult(params, httpreq.filecontent) />
			<cfset result = fixJsonResponse(deserializeJson(httpreq.filecontent)) />
			<cfset result["cached"] = false />
		</cfif>
		 
		<cfset result["params"] = arguments.params />
		<cfreturn addSuccessResult(result) />
	</cffunction>
	
	<cffunction name="upload_post" access="private" output="true" returntype="any" 
			hint="i handle uploading to the api, unfortunately i only return rest xml not json. I never cache a response">
		<cfargument name="params"  type="any" required="no" default="#structnew()#" />
		<cfargument name="url"  type="any" required="no" default="#variables.urls.upload#" />
		<cfset var photo = "" />
		<cfset var httpreq = "" />
		<cfset result = "" />
		<cfset params.api_key = variables.api_key />
		<!--- we need to take the photo out of the params collection because it doesnt get hashed --->
		<cfif structkeyexists(params, "photo")>
			<cfset photo = params.photo />
			<cfset structdelete(params, "photo") />
		</cfif>
		<cfset params.api_sig = createApiSig(params, true) />
		
		<cfhttp url="#arguments.url#" method="post" result="httpreq">
			<cfloop collection="#params#" item="i">
				<cfhttpparam name="#lcase(i)#" type="formfield" value="#params[i]#" />
			</cfloop>
			<cfif len(photo)>
				<cfhttpparam name="photo" type="file" file="#photo#">
			</cfif>
		</cfhttp>
		<!--- put photo back into the params so it can be returned in the response for debugging --->
		<cfset params.photo = photo />
		<cfset result = xmlparse(httpreq.filecontent) />
		<cfreturn result />
	</cffunction>	
	
	
	<cffunction name="cacheResult" access="private" output="false" returntype="void" 
			hint="I decide how and whether to cache the response">
		<cfargument name="params" type="struct" required="true" />
		<cfargument name="result" type="string" required="true" />
		<cfset var obj = "" />
		<cftry>
			<cfif isObject(variables.cache)>
				<cfset obj = fixJsonResponse(deserializeJson(arguments.result)) />
				<cfif NOT isStruct(obj) OR NOT structKeyExists(obj, "stat") OR obj.stat NEQ "OK">
					<cfreturn />
				</cfif>
				<cfif variables.cache.isObjectCache()>
					<cfset variables.cache.saveToCache(params, obj) />
				<cfelse>
					<cfset variables.cache.saveToCache(params, result) />
				</cfif>
			</cfif>
			<cfcatch type="Any">
			
			<cfdump var="#cfcatch#"><cfabort>
			
			</cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="createApiSig" access="private" output="false" returntype="string">
		<cfargument name="params" type="struct" required="true" />
		<cfargument name="removeEmpty" type="boolean" default="false" />
		<cfset var paramlist = listsort(lcase(structkeylist(params)), "TEXT") />
		<cfset var sig = variables.secret />
		<cfset var i = "" />
		<cfloop list="#paramlist#" index="i">
			<cfif isDefined("params.#i#")>
				<cfset sig = sig & i & params[i] />
			<cfelse>
				<cfset structDelete(params, i) />
			</cfif>
		</cfloop>
		<cfreturn lcase(hash(sig)) />
	</cffunction>
	
	<cffunction name="fixJsonResponse" access="private" output="false" returntype="any" 
			hint="i fix single key structs in the json response that look like {_content='foo'} so that the parent element just contains the value 'foo'">
		<cfargument name="data" type="struct" required="true" />
		<cfscript>
		var i = 0;
		if(isStruct(data) AND structKeyList(data) IS "_content") {
			return data._content;
		}
		for(i in data) {
			if(isStruct(data[i])) {
				data[i] = fixJsonResponse(data[i]);
			}
			else if(isArray(data[i])) {
				for(var j=1; j<=arraylen(data[i]); j++) {
					data[i][j] = fixJsonResponse(data[i][j]);
				} 
			}
			else if(i IS "_content" AND isSimpleValue(data[i])) {
				data["value"] = data[i];
				structDelete(data, "_content");
			}
		}
		return data;
		</cfscript>		
	</cffunction>
	
	<cffunction name="addSuccessResult" access="private" output="false" returntype="any">
		<cfargument name="resp" type="struct" />
		<cfset resp["success"] = false />
		<cfif structKeyExists(resp, "stat") AND ucase(resp.stat) IS "OK">
			<cfset resp["success"] = true />
		</cfif>
		<cfreturn resp />
	</cffunction>
	
</cfcomponent>
