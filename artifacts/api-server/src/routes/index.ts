import { Router, type IRouter } from "express";
import healthRouter from "./health";
import webhookRouter from "./webhook";
import mt5Router from "./mt5";
import monitorRouter from "./monitor";
import eaRouter from "./ea";

const router: IRouter = Router();

router.use(healthRouter);
router.use(webhookRouter);
router.use(mt5Router);
router.use(monitorRouter);
router.use(eaRouter);

export default router;
