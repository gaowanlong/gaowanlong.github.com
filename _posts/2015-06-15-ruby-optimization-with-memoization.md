---
layout: post
title: "Ruby optimization with memoization"
description: ""
category: Linux
tags: [ruby]
---

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

While the next day, I run the above command again, find that the data in log is wrong,
the patch doesn't save much acctually:

	ruby -r profile /lkp/lkp/src/sbin/compare -a 4633c9e07b3b7d7fc262a5f59ff635c1f702af6f > /dev/null
	  %   cumulative   self              self     total
	 time   seconds   seconds    calls  ms/call  ms/call  name
	  9.45     0.65      0.31    12350     0.03     0.07  Object#__is_failure
	  8.23     0.92      0.27    11375     0.02     0.08  Object#__is_latency
	  2.44     1.70      0.08      875     0.09     0.67  Object#is_latency
	  0.91     2.17      0.03      912     0.03     0.65  Object#is_failure

Why this happens? Because in the patch V1, I made the cache in the original function
with "Hash.include?" method, and the data in the patch comments is from this patch.
The following is the V1 patch:

	diff --git a/lib/stats.rb b/lib/stats.rb
	index 03ce546..bd58a70 100755
	--- a/lib/stats.rb
	+++ b/lib/stats.rb
	@@ -271,13 +271,17 @@ def load_base_matrix(matrix_path, head_matrix)
	 end
	 
	 def is_failure(stats_field)
	-	$metric_failure.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	-	return false
	+	$__is_failure_cache ||= {}
	+	return $__is_failure_cache[stats_field] if $__is_failure_cache.include?(stats_field)
	+	$metric_failure.each { |pattern| break $__is_failure_cache[stats_field] = true  if stats_field =~ %r{^#{pattern}} }
	+	$__is_failure_cache[stats_field] ||= false
	 end
	 
	 def is_latency(stats_field)
	-	$metric_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
	-	return false
	+	$__is_latency_cache ||= {}
	+	return $__is_latency_cache[stats_field] if $__is_latency_cache.include?(stats_field)
	+	$metric_latency.each { |pattern| break $__is_latency_cache[stats_field] = true if stats_field =~ %r{^#{pattern}} }
	+	$__is_latency_cache[stats_field] ||= false
	 end
	 
	 def should_add_max_latency(stats_field)

Fengguang said that we'd better not intermix the original functionality with caching
functionality. Then I made the V2 patch:(unfortunately not tested)

	diff --git a/lib/stats.rb b/lib/stats.rb
	index 6873495..059fb3e 100755
	--- a/lib/stats.rb
	+++ b/lib/stats.rb
	@@ -270,16 +270,28 @@ def load_base_matrix(matrix_path, head_matrix)
		end
	 end
	 
	-def is_failure(stats_field)
	+def __is_failure(stats_field)
		$metric_failure.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
		return false
	 end
	 
	-def is_latency(stats_field)
	+def is_failure(stats_field)
	+	$__is_failure_cache ||= {}
	+	$__is_failure_cache[stats_field] ||= __is_failure(stats_field)
	+	return $__is_failure_cache[stats_field]
	+end
	+
	+def __is_latency(stats_field)
		$metric_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}} }
		return false
	 end
	 
	+def is_latency(stats_field)
	+	$__is_latency_cache ||= {}
	+	$__is_latency_cache[stats_field] ||= __is_latency(stats_field)
	+	return $__is_latency_cache[stats_field]
	+end
	+
	 def should_add_max_latency(stats_field)
		$metric_add_max_latency.each { |pattern| return true if stats_field =~ %r{^#{pattern}$} }
		return false

The above data is just for this version, says not saved much. Then the following fixup patch
make the data reachs as we expected:

	diff --git a/lib/stats.rb b/lib/stats.rb
	index 1f1fead..f838d25 100755
	--- a/lib/stats.rb
	+++ b/lib/stats.rb
	@@ -277,8 +277,11 @@ end
	 
	 def is_failure(stats_field)
		$__is_failure_cache ||= {}
	-       $__is_failure_cache[stats_field] ||= __is_failure(stats_field)
	-       return $__is_failure_cache[stats_field]
	+       if $__is_failure_cache.include? stats_field
	+               $__is_failure_cache[stats_field]
	+       else
	+               $__is_failure_cache[stats_field] = __is_failure(stats_field)
	+       end
	 end
	 
	 def __is_latency(stats_field)
	@@ -288,8 +291,11 @@ end
	 
	 def is_latency(stats_field)
		$__is_latency_cache ||= {}
	-       $__is_latency_cache[stats_field] ||= __is_latency(stats_field)
	-       return $__is_latency_cache[stats_field]
	+       if $__is_latency_cache.include? stats_field
	+               $__is_latency_cache[stats_field]
	+       else
	+               $__is_latency_cache[stats_field] = __is_latency(stats_field)
	+       end
	 end
	 
	 def should_add_max_latency(stats_field)


The difference is that using "Hash.include?" instead of "||=". Although the test result
says we are saving something according to this cache change, but still not very clear
that why the calls of "is_failure" and "is_latency" can reduce so much.

I guess that when we make a cache inside the method, and ruby can recongnize that we really
want to cache that, it will cache and the result instead of calling the method duplicately. ?
Just a guess, need to dig further....

---
BTW, I find some great articles which describe the memoization optimazation of Ruby:

[The Basics of Ruby Memoization](http://gavinmiller.io/2013/basics-of-ruby-memoization/)

[Advanced Memoization in Ruby](http://gavinmiller.io/2013/advanced-memoization-in-ruby/)

[What Ruby’s \|\|= (Double Pipe / Or Equals) Really Does](http://www.rubyinside.com/what-rubys-double-pipe-or-equals-really-does-5488.html)

[4 Simple Memoization Patterns in Ruby (and One Gem)](http://www.justinweiss.com/blog/2014/07/28/4-simple-memoization-patterns-in-ruby-and-one-gem/)

[Ruby Programming/Syntax/Method Calls](https://en.wikibooks.org/wiki/Ruby_Programming/Syntax/Method_Calls)

---
