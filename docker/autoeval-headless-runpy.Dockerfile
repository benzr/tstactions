FROM ghcr.io/benzr/tstactions/img2:latest

RUN pip3 install numpy matplotlib psutil

COPY tmp/scenes /scenes

COPY run-headless-py.sh /run-headless-py.sh
RUN chmod a+x /run-headless-py.sh


EXPOSE 21212 30100 
ENTRYPOINT ["/run-headless-py.sh"]
# default parameters
# CMD ["-s", "10000", "-q", "/shared/dartv2_final_v0_simple.ttt"]
CMD ["tst"]