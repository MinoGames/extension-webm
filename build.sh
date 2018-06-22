#!/bin/bash
if [ -d "ndll" ]; then
    rm -r ndll
fi
if [ -d "native/obj" ]; then
    rm -r native/obj
fi

cd project
IPHONE_VER=6.0 haxelib run hxcpp Build.xml -Diphoneos

