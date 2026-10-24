"""Restore only the configuration added by this task; never touch save files."""
import asyncio, hashlib, json
from pathlib import Path
from datetime import datetime
from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.house_arrest import HouseArrestService

async def main():
    folder=Path(__file__).resolve().parent
    info=json.loads((folder/'result.json').read_text(encoding='utf-8'))
    ld=await create_using_usbmux(autopair=False,connection_type='USB')
    async with await HouseArrestService.create(ld,info['bundle'],documents_only=True) as afc:
        remote='/Documents/settings.cfg'
        if not await afc.exists(remote):
            print('Already original: settings.cfg is absent.'); return
        content=await afc.get_file_contents(remote)
        if hashlib.sha256(content).hexdigest()!=info['new_sha256']:
            raise RuntimeError('Configuration changed since installation; refusing to overwrite it.')
        target=remote+'.disabled_'+datetime.now().strftime('%Y%m%d_%H%M%S')
        await afc.rename(remote,target)
        if await afc.exists(remote): raise RuntimeError('Restoration verification failed.')
        (folder/'restoration.json').write_text(json.dumps({'restored':True,'retained_disabled_copy':target},indent=2),encoding='utf-8')
        print('Original configuration restored; saves unchanged.')
    await ld.close()

asyncio.run(asyncio.wait_for(main(),30))
