version 4.7

class NotUaS_TraumaKitReplacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let T = e.Thing;

		if (T && T.GetClassName() == "UaS_TraumaKit")
		{
			let trk = UaS_TraumaKit(T);

			if (trk.Owner)
			{
				let tk = NotUaS_TraumaKit(trk.Owner.FindInventory("NotUaS_TraumaKit"));
				trk.Owner.GiveInventory("NotUaS_TraumaKit", 1);

				if (tk)
				{
					tk.weaponStatus[tk.TKS_PAINKILLER] += trk.weaponStatus[trk.TKS_PAINKILLER];
					tk.weaponStatus[tk.TKS_SALINE] += trk.weaponStatus[trk.TKS_SALINE];
					tk.weaponStatus[tk.TKS_BIOFOAM] += trk.weaponStatus[trk.TKS_BIOFOAM];
					tk.weaponStatus[tk.TKS_STAPLES] += trk.weaponStatus[trk.TKS_STAPLES];
				}
			}
			else Actor.Spawn("NotUaS_TraumaKit", trk.pos);
			trk.destroy();
		}
	}
}

class NotUaS_TraumaKit : UaS_TraumaKit
{
	override void ActualPickup(Actor other, bool silent)
	{
		let tk = HDWeapon(other.FindInventory("NotUaS_TraumaKit"));
		if (tk)
		{
			other.A_Log("\cgRefilled Trauma Kit supplies", true);
			A_StartSound("weapons/pocket");
			tk.weaponStatus[TKS_PAINKILLER] += weaponStatus[TKS_PAINKILLER];
			tk.weaponStatus[TKS_SALINE] += weaponStatus[TKS_SALINE];
			tk.weaponStatus[TKS_BIOFOAM] += weaponStatus[TKS_BIOFOAM];
			tk.weaponStatus[TKS_STAPLES] += weaponStatus[TKS_STAPLES];
			self.Destroy();
			return;
		}

		Super.ActualPickup(other, silent);
	}

	// try to not use statusmessage
	override void DoEffect()
	{
		if (!(Owner.Player.ReadyWeapon is "NotUaS_TraumaKit")) return;
		statusMessage = "";

		SetHelpText();
		SetPatient();
		CycleWounds();
		CycleTools();
		HandleSupplies();

		switch (weaponstatus[TK_SELECTED])
		{
			case T_PAINKILLER:
				HandlePainkiller();
				break;
			case T_SALINE:
				HandleSaline();
				break;
			case T_FORCEPS:
				HandleForceps();
				break;
			case T_BIOFOAM:
				HandleBiofoam();
				break;
			case T_STAPLER:
				HandleStapler();
				break;
			case T_SUTURES:
				HandleSutures();
				break;
			case T_SCALPEL:
				HandleScalpel();
				break;
		}

		TickMessages();
	}

	// Use this instead
	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl)
	{
		if (!patient) return;

		// Floats for precision (also required for centering)
		float textHeight = sb.pSmallFont.mFont.GetHeight() * notuas_hudscale;
		float padding = 2 * notuas_hudscale;
		float padStep = textHeight + padding;
		float halfStep = padStep / 2;
		float baseOffset = (-7 * textHeight) + (-3 * padding);
		Vector2 hudScale = (notuas_hudscale, notuas_hudscale);

		// Header
		sb.DrawString(
			sb.pSmallFont,
			"--- \cyTrauma Kit\c- ---\n",
			(0, baseOffset),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			Font.CR_GRAY,
			scale: hudScale
		);
		sb.DrawString(
			sb.pSmallFont,
			"Treating \cg" .. patient.player.GetUsername(),
			(0, baseOffset + textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			Font.CR_GRAY,
			scale: hudScale
		);

		// Wound List
		int woundListOffsetX = -12;
		float woundListOffsetY = baseOffset + (3 * textHeight) + (3 * padStep);

		if (wh.critWounds.Size() == 0)
		{
			sb.DrawString(
				sb.pSmallFont,
				"No treatable wounds",
				(0, woundListOffsetY),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_GRAY,
				scale: hudScale
			);
		}
		else
		{
			Array<string> wounds;
			int idx = (currentWound)? wh.critWounds.Find(currentWound) : 0;
			int loopMin = Min(idx - 2, wh.critWounds.Size() - 5);
			int loopMax = Max(idx + 2, 4);

			// Compile list
			for (int i = loopMin; i <= loopMax; i++)
			{
				if (i < 0 || i > wh.critWounds.Size() - 1) continue;

				string textColour;
				if (AverageStatus(wh.critWounds[i]) >= 15)
				{
					textColour = (i == idx)? "\ca" : "\cr"; // Red / Dark Red
				}
				else
				{
					textColour = (i == idx)? "\cd" : "\cq"; // Green / Dark Green
				}

				string pointer = (i == idx)? " <" : "";
				wounds.push(textColour..wh.critWounds[i].description..pointer);
				woundListOffsetY -= halfStep;
			}
			woundListOffsetY += halfStep; // accommodation

			// Top overflow dot
			if (loopMin > 0)
			{
				sb.DrawString(
					sb.pSmallFont,
					". . .",
					(woundListOffsetX, woundListOffsetY - padStep),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
					Font.CR_GRAY,
					scale: hudScale
				);
			}

			// The actual list
			for (int i = 0; i < wounds.Size(); i++)
			{
				sb.DrawString(
					sb.pSmallFont,
					wounds[i],
					(woundListOffsetX, woundListOffsetY),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
					scale: hudScale
				);

				woundListOffsetY += padStep;
			}

			// Bottom overflow dot
			if (loopMax < wh.critWounds.Size() - 1)
			{
				sb.DrawString(
					sb.pSmallFont,
					". . .",
					(woundListOffsetX, woundListOffsetY),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
					Font.CR_GRAY,
					scale: hudScale
				);
			}
		}

		// Wound info
		if (currentWound)
		{
			int woundInfoOffsetX = 12;
			float woundInfoOffsetY = baseOffset + (3 * textHeight) + (3 * padStep);
			Array<string> status;
			if (currentWound.open <= 0)
			{
				status.Push("-The wound is "..GetStatusColour(currentWound.open).."closed\c-.");
			}
			else
			{
				status.Push("-The wound is "..GetStatusColour(currentWound.open).."open");

				string tmpStr;

				// Painkillers
				tmpStr = "not numbed.";
				if (currentWound.painkiller >= 75) tmpStr = "numbed";
				else if (currentWound.painkiller >= 50) tmpStr = "mostly numbed";
				else if (currentWound.painkiller >= 25) tmpStr = "somewhat numbed";

				status.Push("-It is "..GetStatusColour(100 - currentWound.painkiller)..tmpStr);
				woundInfoOffsetY -= halfStep;

				// Dirty
				if (currentWound.dirty >= 0)
				{
					tmpStr = "completely clean";
					if (currentWound.dirty >= 65) tmpStr = "filthy";
					else if (currentWound.dirty >= 55) tmpStr = "very dirty";
					else if (currentWound.dirty >= 45) tmpStr = "somewhat dirty";
					else if (currentWound.dirty >= 35) tmpStr = "a bit dirty";
					else if (currentWound.dirty >= 25) tmpStr = "almost clean";
					else if (currentWound.dirty >= 15) tmpStr = "acceptably clean";

					status.Push("-It is "..GetStatusColour(currentWound.dirty)..tmpStr);
					woundInfoOffsetY -= halfStep;
				}

				// Obstructions
				if (currentWound.obstructed >= 0)
				{
					tmpStr = "no apparent obstructions";
					if (currentWound.obstructed >= 55) tmpStr = "many obstructions";
					else if (currentWound.obstructed >= 45) tmpStr = "several obstructions";
					else if (currentWound.obstructed >= 35) tmpStr = "a few obstructions";
					else if (currentWound.obstructed >= 25) tmpStr = "some obstructions";
					else if (currentWound.obstructed >= 15) tmpStr = "very little obstructions";

					status.Push("-There are "..GetStatusColour(currentWound.obstructed)..tmpStr);
					woundInfoOffsetY -= halfStep;
				}

				// Cavity
				if (currentWound.cavity >= 0)
				{
					tmpStr = "no treatable tissue damage";
					if (currentWound.cavity >= 85) tmpStr = "severe tissue damage";
					else if (currentWound.cavity >= 65) tmpStr = "significant tissue damage";
					else if (currentWound.cavity >= 45) tmpStr = "moderate tissue damage";
					else if (currentWound.cavity >= 25) tmpStr = "some tissue damage";
					else if (currentWound.cavity >= 15) tmpStr = "little tissue damage";

					status.Push("-There is "..GetStatusColour(currentWound.cavity)..tmpStr);
					woundInfoOffsetY -= halfStep;
				}
			}

			for (int i = 0; i < status.Size(); i++)
			{
				sb.DrawString(
					sb.pSmallFont,
					status[i],
					(woundInfoOffsetX, woundInfoOffsetY),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
					Font.CR_GRAY,
					scale: hudScale
				);

				woundInfoOffsetY += padStep;
			}
		}

		// Tool info
		float toolInfoOffset = baseOffset + (4 * textHeight) + (7 * padStep);
		Array<string> trueStatusMessage;
		statusMessage.Split(trueStatusMessage, "\n"); // temporary workaround

		for (int i = 0; i < trueStatusMessage.Size(); i++)
		{
			sb.DrawString(
				sb.pSmallFont,
				trueStatusMessage[i],
				(0, toolInfoOffset),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				scale: hudScale
			);

			toolInfoOffset += textHeight;
		}
	}

	// shitty functions to work around not being able to use stuff in ui context
	ui int AverageStatus(WoundInfo wi)
	{
		int retValue, counted;
		if (wi.dirty >= 0)
		{
			retValue += wi.dirty;
			counted++;
		}
		if (wi.obstructed >= 0)
		{
			retValue += wi.obstructed;
			counted++;
		}
		if (wi.cavity >= 0)
		{
			retValue += wi.cavity;
			counted++;
		}
		if (wi.open >= 0)
		{
			retValue += wi.open;
			counted++;
		}

		return retValue / counted;
	}

	ui string GetStatusColour(int amount)
	{
		if (amount >= 90) return "\cm";
		if (amount >= 80) return "\cr";
		if (amount >= 70) return "\ca";
		if (amount >= 60) return "\cx";
		if (amount >= 50) return "\ci";
		if (amount >= 40) return "\ck";
		if (amount >= 30) return "\cs";
		if (amount >= 20) return "\cq";
		if (amount >= 10) return "\cd";
		if (amount >= 0) return "\cd";
		return "\cj";
	}
}
