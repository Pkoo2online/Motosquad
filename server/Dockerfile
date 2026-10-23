FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

EXPOSE 4040
ENV PORT=4040

CMD ["node", "server.js"]
