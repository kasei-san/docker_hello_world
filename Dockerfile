FROM nginx:1.17.8-alpine
RUN echo "Hello, World" > /usr/share/nginx/html/index.html
EXPOSE 80
