import { Router, type IRouter } from "express";
import healthRouter from "./health";
import webhookRouter from "./webhook";
import mt5Router from "./mt5";
import monitorRouter from "./monitor";

const router: IRouter = Router();

router.use(healthRouter);
router.use(webhookRouter);
router.use(mt5Router);
router.use(monitorRouter);

export default router;
