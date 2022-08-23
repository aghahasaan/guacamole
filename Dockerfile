FROM debian

COPY install_db.sh /install_db.sh
RUN chmod +x /install_db.sh
RUN /install_db.sh #> install.log 2> error.log
RUN rm /install_db.sh
RUN mkdir -p /guacamole
#RUN cp /install.log /guacamole/install.log && rm /install.log && cp /error.log /guacamole/error.log && rm /error.log
COPY start_db.sh /guacamole/start_db.sh
RUN chmod +x /guacamole/start_db.sh
RUN /guacamole/start_db.sh
EXPOSE 8080
CMD ["/usr/bin/supervisord"]
