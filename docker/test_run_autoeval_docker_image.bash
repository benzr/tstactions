docker run --rm -v /home/newubu/Teach/dartv2/scenes:/shared -p 30100:30100 -p 21212:21212 -it --env DISPLAY=:1 --volume /tmp/.X11-unix:/tmp/.X11-unix --name autoeval autoeval:lastest  -s 20000 -q 
