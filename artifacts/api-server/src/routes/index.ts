import { Router, type IRouter } from "express";
import healthRouter from "./health";
import webhookRouter from "./webhook";
import mt5Router from "./mt5";

const router: IRouter = Router();

router.use(healthRouter);
router.use(webhookRouter);
router.use(mt5Router);

export default router;
