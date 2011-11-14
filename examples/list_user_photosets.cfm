<cfinclude template="config.cfm" />

<cfif structKeyExists(url, "photoset_id")>

	<cfset info = cflickr.photosets_getInfo(photoset_id=url.photoset_id, auth_token=token) />
	<cfset photos = cflickr.photosets_getPhotos(photoset_id=url.photoset_id, auth_token=token) />
	
	<h3>Photos in set
		<cfoutput>
		<a href="http://www.flickr.com/photos/#userid#/sets/#url.photoset_id#/">#info.photoset.title#</a>
		</cfoutput>
	</h3>
	
	<div style="width:400px;">
	<cfloop from="1" to="#arraylen(photos.photoset.photo)#" index="i">
		<cfset p = photos.photoset.photo[i] />
		<cfoutput>
		<a href="http://flickr.com/photo.gne?id=#p.id#"><img src="#cflickr.getPhotoUrl(p, 's')#" /></a>
		</cfoutput> 
	</cfloop>

	</div>	

<cfelse>

	<cfset resp = cflickr.photosets_getList(user_id=userid, auth_token=token) />
	<h3>Your photosets<h3>
	<div style="width:400px;">
	<cfloop from="1" to="#arraylen(resp.photosets.photoset)#" index="i">
		<cfset ps = resp.photosets.photoset[i] />
		
		<cfoutput>
		<a href="?photoset_id=#ps.id#"><img src="#cflickr.getPhotoUrl(ps, 's')#" /></a>
		</cfoutput>
	
	</cfloop>
	</div>


</cfif>

