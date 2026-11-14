import { createAccountDeletionApp, productionDependencies } from "./index.js";

const dependencies = productionDependencies();
const app = createAccountDeletionApp(dependencies);

app.listen(dependencies.config.port);
