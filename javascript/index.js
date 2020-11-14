exports.handler = (event, context, callback) => {
    console.log('Received an event:', JSON.stringify(event, null, 2));
    callback(null, {statusCode: 200, body: "Hello, World!"});
  };