---
layout: post
title: "Ruby optimization with memoization"
description: ""
category: 
tags: []
---
{% include JB/setup %}

In this patch: [stats.rb: make cache for is_failure and is_latency](https://github.com/gaowanlong/lkp-tests/commit/2e910237d933bfbaa14ad64ac6b005151f70354a),
as the comment said:

	$ ruby -r profile sbin/compare -a 4633c9e07b3b7d7fc262a5f59ff635c1f702af6f

	Before:
	  %   cumulative   self              self     total
	 time   seconds   seconds    calls  ms/call  ms/call  name
	 11.50     0.33      0.33    12750     0.03     0.07  Object#is_failure
	  8.36     0.89      0.24    11375     0.02     0.08  Object#is_latency

	After: (is_failure and is_latency cache)
	  %   cumulative   self              self     total
	 time   seconds   seconds    calls  ms/call  ms/call  name
	  1.39     1.39      0.03     1945     0.02     0.05  Object#is_failure
	  1.39     1.33      0.03     2099     0.01     0.03  Object#is_latency

We are trying to optimize the functions which are called many
times, and we are knowning that many calls may be with the same argument. Then the
widely used method in our repo is creating a global Hash key cache which cache the
{key: result} pair so that next call with the same argument can directly returned
from the cache without any computing.

From the data we can see that the run time percentage is reduced, but why the cumulative
seconds increased? And why the calls reduce so much? The cache inside a function can
even reduce the calls number of this function? It's interesing and a remaining question
for me to dig more...


---
BTW, I find some great articles which describe the memoization optimazation of Ruby:

[The Basics of Ruby Memoization](http://gavinmiller.io/2013/basics-of-ruby-memoization/)

[Advanced Memoization in Ruby](http://gavinmiller.io/2013/advanced-memoization-in-ruby/)

[What Ruby’s \|\|= (Double Pipe / Or Equals) Really Does](http://www.rubyinside.com/what-rubys-double-pipe-or-equals-really-does-5488.html)

[4 Simple Memoization Patterns in Ruby (and One Gem)](http://www.justinweiss.com/blog/2014/07/28/4-simple-memoization-patterns-in-ruby-and-one-gem/)

---
