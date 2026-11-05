FROM node:24-alpine
WORKDIR /app
RUN chown node:node /app
USER node
COPY --chown=node:node package*.json ./
RUN npm ci
COPY --chown=node:node . .
RUN npm test && npm run build
EXPOSE 3030
CMD ["npm", "run", "dev", "--", "--remote", "--bind", "0.0.0.0"]
