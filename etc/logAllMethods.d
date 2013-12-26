#!/usr/sbin/dtrace -s


macruby$target:::method-entry
/ copyinstr(arg0) == "WebViewDelegate" /
{
  printf("%s", copyinstr(arg1));
}


/*objc$target:::entry
{
  printf("%s %s\n", probemod, probefunc);
}
*/