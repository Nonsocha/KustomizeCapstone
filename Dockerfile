FROM nginx:latest

COPY 2137_barista_cafe/* /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


