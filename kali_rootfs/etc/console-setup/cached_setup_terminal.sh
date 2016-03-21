#!/bin/sh

{
printf '\033%%@' 
} < /dev/tty${1#vcs} > /dev/tty${1#vcs}
