import Inventory2Icon from '@mui/icons-material/Inventory2'
import AppBar from '@mui/material/AppBar'
import Box from '@mui/material/Box'
import Toolbar from '@mui/material/Toolbar'
import Typography from '@mui/material/Typography'
import type { AuthUser } from '../../types'
import AccountMenu from './AccountMenu'

interface DashboardHeaderProps {
  user: AuthUser
  onLogout: () => void
}

export default function DashboardHeader({ user, onLogout }: DashboardHeaderProps) {
  return (
    <AppBar
      position="sticky"
      color="inherit"
      elevation={0}
      sx={{ borderBottom: '1px solid', borderColor: 'divider' }}
    >
      <Toolbar sx={{ gap: 2, px: { xs: 2, md: 3 } }}>
        <Box
          sx={{
            width: 40,
            height: 40,
            display: 'grid',
            placeItems: 'center',
            borderRadius: 2,
            color: 'primary.contrastText',
            bgcolor: 'primary.main',
            flex: '0 0 auto',
          }}
        >
          <Inventory2Icon />
        </Box>
        <Box sx={{ minWidth: 0, flexGrow: 1 }}>
          <Typography variant="h6" noWrap>
            Inventory Build Console
          </Typography>
        </Box>
        <AccountMenu user={user} onLogout={onLogout} />
      </Toolbar>
    </AppBar>
  )
}