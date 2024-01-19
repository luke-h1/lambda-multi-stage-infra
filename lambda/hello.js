exports.handler = async (event, context) => {
  console.log("event", event);
  console.log("context", context);

  const response = {
    statusCode: 200,
    body: JSON.stringify("Hello from aws lambdas 🚀 🧨"),
  };
  return response;
};
