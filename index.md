---
layout: page
title: Home
---
{% include JB/setup %}

```
 _____________________
< Welcome to my blog! >
 ---------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/ .......output from cowsay
```

{% for post in site.posts offset: 0 limit: 10 %}
<h2>
<a href="{{ site.prefix }}{{ post.url }}">{{ post.title }}</a>
</h2>
{{ post.date | date_to_string }}
{{ post.content }}
{% endfor %}
