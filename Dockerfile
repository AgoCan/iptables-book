FROM node:10.24.1-alpine3.11 as builder
RUN npm install gitbook-cli -g 

WORKDIR /app
COPY book.json .
RUN gitbook install
COPY . /app

RUN gitbook build 

FROM nginx
COPY --from=builder /app/_book /usr/share/nginx/html
