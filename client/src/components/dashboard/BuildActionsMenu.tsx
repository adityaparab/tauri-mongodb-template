import { useState, type MouseEvent } from 'react'
import DownloadIcon from '@mui/icons-material/Download'
import MoreVertIcon from '@mui/icons-material/MoreVert'
import IconButton from '@mui/material/IconButton'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'
import Menu from '@mui/material/Menu'
import MenuItem from '@mui/material/MenuItem'
import Tooltip from '@mui/material/Tooltip'
import type { BuildRecord } from '../../types'

interface BuildActionsMenuProps {
  record: BuildRecord
  isDownloading: boolean
  onDownload: (record: BuildRecord) => void
}

export default function BuildActionsMenu({ record, isDownloading, onDownload }: BuildActionsMenuProps) {
  const [anchorElement, setAnchorElement] = useState<HTMLElement | null>(null)
  const isMenuOpen = Boolean(anchorElement)

  const handleOpen = (event: MouseEvent<HTMLElement>) => {
    setAnchorElement(event.currentTarget)
  }

  const handleClose = () => {
    setAnchorElement(null)
  }

  const handleDownload = () => {
    handleClose()
    onDownload(record)
  }

  return (
    <>
      <Tooltip title="Build actions">
        <IconButton aria-label="Build actions" onClick={handleOpen} size="small">
          <MoreVertIcon />
        </IconButton>
      </Tooltip>
      <Menu anchorEl={anchorElement} open={isMenuOpen} onClose={handleClose}>
        <MenuItem disabled={!record.canDownload || isDownloading} onClick={handleDownload}>
          <ListItemIcon>
            <DownloadIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>{isDownloading ? 'Preparing artifact' : 'Download artifact'}</ListItemText>
        </MenuItem>
      </Menu>
    </>
  )
}