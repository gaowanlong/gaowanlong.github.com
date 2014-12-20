---
layout: post
title: "SPA3102 with asterisk"
description: ""
category: 
tags: []
---
{% include JB/setup %}


After asterisk 12, we use pjsip instead of sip.

Following is a pjsip.conf with template used.

	 ;===============TRANSPORT
	 
	[simpletrans]
	type=transport
	protocol=udp
	bind=0.0.0.0
	 
	;===============ENDPOINT TEMPLATES
	 
	[endpoint-basic](!)
	type=endpoint
	transport=simpletrans
	context=internal
	disallow=all
	allow=ulaw,alaw
	 
	[auth-userpass](!)
	type=auth
	auth_type=userpass
	 
	[aor-single-reg](!)
	type=aor
	max_contacts=1
	 
	;===============EXTENSION fxs
	 
	[200](endpoint-basic)
	auth=auth200
	aors=200
	 
	[auth200](auth-userpass)
	password=123456
	username=200
	 
	[200](aor-single-reg)
	 
	;===============EXTENSION fxo
	 
	[fxo](endpoint-basic)
	auth=authfxo
	aors=fxo
	 
	[authfxo](auth-userpass)
	password=123456
	username=fxo
	 
	[fxo](aor-single-reg)
	
	
	;=================== EXTENSION ip
	[201](endpoint-basic)
	auth=auth201
	aors=201
	
	[auth201](auth-userpass)
	password=123
	username=201
	
	[201](aor-single-reg)



Following is a extension.conf(Dial Plan):

	[internal] 
	exten => 200,1,Dial(PJSIP/200)
	exten => 201,1,Dial(PJSIP/201)
	exten => _0.,1,Dial(PJSIP/${EXTEN:1}@fxo)
	;phone number that start with 0 are sent to Linksys -> landline 
	;exten => group,1,Dial(PJSIP/200,PJSIP/201)
	exten => group,1,Dial(PJSIP/200, 30, m)
	  same => n,Answer()
	  same => n,Wait(1)
	  same => n,Background(custom-menu)
	  same => n,WaitExten(10)
	  same => n,Hangup()
	exten => 1,1,VoiceMail(1234@default)
	  same => n,Hangup()
	
	exten => 5555,1,Answer(500)
	  same => n,Record(en/custom-menu.gsm)
	  same => n,Wait(1)
	  same => n,Playback(custom-menu)
	  same => n,Hangup()
	
	exten => 9999,1,VoiceMailMain(1234@default)
	  same => n,Hangup()





The same conf which use chan_sip is like following:

	[fxo]
	type=friend
	secret=123
	qualify=yes
	nat=no
	host=dynamic
	canreinvite=no
	context=internal
	[200]
	type=friend
	secret=123
	qualify=yes
	nat=no
	host=dynamic
	canreinvite=no
	context=internal
	[201]
	type=friend
	secret=123
	qualify=yes
	nat=no
	host=dynamic
	canreinvite=no
	context=internal

For SPA3102, we should notice the Dial Plans of PSTN line:
(S0<:group@my.asterisk.server>)		(Dial group on my asterisk server)
