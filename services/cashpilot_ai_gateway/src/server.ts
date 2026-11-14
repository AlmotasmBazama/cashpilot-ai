import { createGatewayApp, productionDependencies } from "./index.js";

const dependencies = productionDependencies();
const app = createGatewayApp(dependencies);

app.listen(dependencies.config.port);
